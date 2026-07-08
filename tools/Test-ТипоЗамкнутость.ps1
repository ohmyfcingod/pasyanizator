# Test-ТипоЗамкнутость.ps1 — ГЕЙТ G5 (такт 6): ПРЯМАЯ типозамкнутость по MDClasses-экспорту.
# Заменяет regex-по-EDT-src гейта Т (Test-ТипоВрезка) на парсинг РЕАЛЬНОГО designer-XML
# (export_configuration_to_xml). Экспорт = то, что накатано, — авторитетнее диска.
#
# Две проверки:
#  1. РЕЗОЛВИМОСТЬ (0 висячих типов). Каждый тип из банкТипов карты + ссылочныеТипы реквизитов и
#     допСведений видов + типы САМИХ генерённых видов (CatalogRef.<Вид>) обязан резолвиться в
#     существующий <Папка>/<Имя>.xml экспорта. Висячий тип = врезали ссылку на несуществующий объект.
#  2. ВРЕЗКА-ПАРНОСТЬ. Все Пасьянизатор-генерённые виды сделаны ОДНИМ генератором с ОДНИМ deny-list,
#     значит их «тип-след» (множество файлов-составов, несущих типизированную ссылку на вид в 5
#     форматах) обязан СОВПАДАТЬ. Расхождение = врезка типа не долетела до какого-то состава у
#     одного из видов (то, что косвенный гейт Т ловил матрицей по КартаВрезок; здесь — по факту XML).
#
# Коды: 0 = зелено (типозамкнуто), 2 = красно, 1 = ошибка. Требует pwsh 7.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Экспорт,             # каталог MDClasses-XML (export_configuration_to_xml)
    [string]$Карта,                                       # JSON-карта: банкТипов + ссылочныеТипы для проверки резолвимости
    [string]$HitsOut = 'E:\1CRoot\Пасьянс\Test-ТипоЗамкнутость.hits.tsv',   # артефакт — вне репо
    [string]$МаркерВида = 'Пасьянизатор из вида'          # по нему опознаём свои генерённые виды в Catalogs
)

$ErrorActionPreference = 'Stop'
$ошибки = [System.Collections.Generic.List[string]]::new()
$hits = [System.Collections.Generic.List[string]]::new()
function Fail([string]$м) { $script:ошибки.Add($м); Write-Host "  FAIL $м" -ForegroundColor Red }
function Ok([string]$м) { Write-Host "  ok   $м" -ForegroundColor Green }

if (-not (Test-Path -LiteralPath $Экспорт)) { Write-Host "Нет каталога экспорта: $Экспорт" -ForegroundColor Red; exit 1 }
$экспортFull = (Resolve-Path -LiteralPath $Экспорт).Path.TrimEnd('\', '/')

Write-Host "=== Test-ТипоЗамкнутость (гейт G5): $экспортFull ==="

# cfg-класс -> папка вида (снято с движка Расхламлялки Test-Типозамкнутость; полный набор).
$classToKind = @{
    Catalog='Catalogs'; Document='Documents'; Enum='Enums'
    InformationRegister='InformationRegisters'; AccumulationRegister='AccumulationRegisters'
    AccountingRegister='AccountingRegisters'; CalculationRegister='CalculationRegisters'
    ChartOfCharacteristicTypes='ChartsOfCharacteristicTypes'; Characteristic='ChartsOfCharacteristicTypes'
    ChartOfAccounts='ChartsOfAccounts'; ChartOfCalculationTypes='ChartsOfCalculationTypes'
    DefinedType='DefinedTypes'; ExchangePlan='ExchangePlans'; Constant='Constants'
    FunctionalOption='FunctionalOptions'; EventSubscription='EventSubscriptions'
    DataProcessor='DataProcessors'; Report='Reports'; Role='Roles'; CommonModule='CommonModules'
    BusinessProcess='BusinessProcesses'; Task='Tasks'; Sequence='Sequences'
    DocumentJournal='DocumentJournals'; Subsystem='Subsystems'; CommonAttribute='CommonAttributes'
    WebService='WebServices'; HTTPService='HTTPServices'; ScheduledJob='ScheduledJobs'
    CommonForm='CommonForms'; CommonCommand='CommonCommands'; SessionParameter='SessionParameters'
    Style='Styles'; StyleItem='StyleItems'; CommonPicture='CommonPictures'; CommonTemplate='CommonTemplates'
    XDTOPackage='XDTOPackages'; FilterCriterion='FilterCriteria'; SettingsStorage='SettingsStorages'
    FunctionalOptionsParameter='FunctionalOptionsParameters'; DocumentNumerator='DocumentNumerators'
    ChartOfCalculationType='ChartsOfCalculationTypes'
}

function Read-SharedText([string]$Path) {
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try { $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true); try { $sr.ReadToEnd() } finally { $sr.Dispose() } }
    finally { $fs.Dispose() }
}

# --- Набор существующих объектов экспорта: "Папка|Имя" ---
$существует = [System.Collections.Generic.HashSet[string]]::new()
foreach ($folder in ($classToKind.Values | Select-Object -Unique)) {
    $d = Join-Path $экспортFull $folder
    if (-not (Test-Path -LiteralPath $d)) { continue }
    foreach ($f in (Get-ChildItem -LiteralPath $d -Filter *.xml -File -ErrorAction SilentlyContinue)) {
        [void]$существует.Add("$folder|$($f.BaseName)")
    }
}
Write-Host "  объектов в экспорте: $($существует.Count)"

function Резолв([string]$ТипСсылки) {
    # "CatalogRef.X" / "cfg:DocumentObject.Y" / "ChartOfCharacteristicTypesRef.Z" -> "Папка|Имя" или $null
    $t = $ТипСсылки -replace '^cfg:', ''
    if ($t -notmatch '^([A-Za-z]+?)(Ref|Object|Selection|List|Manager|RecordManager|RecordSet|RecordKey|RoutePointRef)?\.(.+)$') { return $null }
    $класс = $Matches[1]; $имя = $Matches[3]
    $папка = $classToKind[$класс]
    if (-not $папка) { return "??|$ТипСсылки" }   # неизвестный класс — вернём флаг, чтобы не молчать
    return "$папка|$имя"
}

# ================= 1. РЕЗОЛВИМОСТЬ =================
$типыКПроверке = [System.Collections.Generic.List[string]]::new()
$генвиды = @()
if ($Карта) {
    if (-not (Test-Path -LiteralPath $Карта)) { Write-Host "Нет карты: $Карта" -ForegroundColor Red; exit 1 }
    $к = Get-Content -LiteralPath $Карта -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
    @($к.банкТипов) | Where-Object { $_ } | ForEach-Object { $типыКПроверке.Add([string]$_) }
    foreach ($в in $к.виды) {
        $генвиды += $в.справочник.имя
        # NB: тип самого вида (CatalogRef.<Вид>) НЕ проверяем на резолвимость — вид карты мог не
        # входить в текущий прогон генерации (у Test-Карта та же логика с -ВидыПрогона). Проверяем
        # только ТИПЫ, НА КОТОРЫЕ ВИД ССЫЛАЕТСЯ (банкТипов + ссылочныеТипы реквизитов/допСведений).
        foreach ($р in (@($в.реквизиты) + @($в.допСведения))) {
            foreach ($т in @($р.типы)) { if ($т.ссылочныйТип) { $типыКПроверке.Add([string]$т.ссылочныйТип) } }
        }
    }
}
$типыУник = $типыКПроверке | Select-Object -Unique
$висячих = 0
foreach ($т in $типыУник) {
    $ключ = Резолв $т
    if ($null -eq $ключ) { continue }   # не ссылочный/непарсируемый — пропускаем
    if ($ключ -like '??|*') { Fail "тип '$т': неизвестный класс (нет в classToKind)"; continue }
    if (-not $существует.Contains($ключ)) {
        $висячих++; $hits.Add("резолв`t$т`t$ключ`t(карта)")
        Fail "висячий тип: '$т' -> нет объекта '$($ключ -replace '\|','/')' в экспорте"
    }
}
if ($висячих -eq 0 -and $Карта) { Ok "резолвимость: все типы карты ($($типыУник.Count)) существуют в экспорте" }
if (-not $Карта) { Write-Host "  (карта не задана — проверка резолвимости пропущена)" -ForegroundColor Yellow }

# ================= 2. ВРЕЗКА-ПАРНОСТЬ между генерёнными видами =================
# опознаём свои виды по маркеру в Catalogs (если карта не задала — берём из экспорта)
$каталогВидов = Join-Path $экспортFull 'Catalogs'
$своиВиды = @()
if (Test-Path -LiteralPath $каталогВидов) {
    foreach ($f in (Get-ChildItem -LiteralPath $каталогВидов -Filter *.xml -File)) {
        if ((Read-SharedText $f.FullName).Contains($МаркерВида)) { $своиВиды += $f.BaseName }
    }
}
Write-Host "  генерённых видов (по маркеру): $($своиВиды.Count) [$($своиВиды -join ', ')]"

if ($своиВиды.Count -lt 2) {
    Write-Host "  (парность требует >= 2 генерённых видов — пропущено; резолвимости достаточно)" -ForegroundColor Yellow
} else {
    # 5 форматов типизированной ссылки (снято с движка Расхламлялки), но матчим ИМЯ конкретного вида.
    # тип-след вида = множество ОТНОСИТЕЛЬНЫХ путей файлов-СОСТАВОВ, где вид упомянут типизированно.
    # ИСКЛЮЧАЕМ: Configuration.xml (реестр) + СОБСТВЕННЫЕ файлы ЛЮБОГО генерённого вида
    # (Catalogs\<Вид>.xml и всё поддерево Catalogs\<Вид>\… — формы/модули вида ссылаются на себя,
    # это не врезка в чужой состав; иначе списочная форма Договора «ломает» парность с Гарантийным).
    # ЕДИНЫЙ ПРОХОД (масштаб 52 вида): читаем каждый файл ОДИН раз, регэкспы 5 форматов ЗАХВАТЫВАЮТ
    # имя (группа 2) — если имя ∈ генерённые виды, файл добавляется в его тип-след. O(файлы), не O(файлы×виды).
    $classAlt = (($classToKind.Keys | Sort-Object { $_.Length } -Descending) | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $nm = '([\wЀ-ӿ]+)'
    $форматы = @(
        [regex]("cfg:($classAlt)(?:Ref|Object|Selection|List|Manager|RecordManager|RecordSet|RecordKey|RoutePointRef)?\.$nm")
        [regex]("<xr:Item[^>]*>($classAlt)\.$nm</xr:Item>")
        [regex]("<Metadata>($classAlt)\.$nm</Metadata>")
        [regex]("<Location>($classAlt)\.$nm")
        [regex]("<Source>($classAlt)\.$nm")
    )
    $свойНабор = [System.Collections.Generic.HashSet[string]]::new(); $своиВиды | ForEach-Object { [void]$свойНабор.Add($_) }
    $своиПрефиксы = @($своиВиды | ForEach-Object { "Catalogs\$_" })   # Catalogs\<Вид>.xml и Catalogs\<Вид>\
    function Свой-Файл([string]$rel) {
        if ($rel -eq 'Configuration.xml') { return $true }
        foreach ($pfx in $своиПрефиксы) { if ($rel -eq "$pfx.xml" -or $rel.StartsWith("$pfx\")) { return $true } }
        return $false
    }
    $следы = @{}; $своиВиды | ForEach-Object { $следы[$_] = [System.Collections.Generic.HashSet[string]]::new() }
    foreach ($f in (Get-ChildItem -LiteralPath $экспортFull -Recurse -Filter *.xml -File -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($экспортFull.Length).TrimStart('\', '/')
        if (Свой-Файл $rel) { continue }
        $text = Read-SharedText $f.FullName
        foreach ($re in $форматы) {
            foreach ($m in $re.Matches($text)) {
                $имя = $m.Groups[2].Value
                if ($свойНабор.Contains($имя)) { [void]$следы[$имя].Add($rel) }
            }
        }
    }
    foreach ($в in $своиВиды) { Write-Host "    $($в): врезан в $($следы[$в].Count) составов" }
    # эталон = вид с максимальным следом (объединение — «полный» набор целей врезки)
    $объединение = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($в in $своиВиды) { foreach ($p in $следы[$в]) { [void]$объединение.Add($p) } }
    $расхождений = 0
    foreach ($в in $своиВиды) {
        $недостаёт = @($объединение | Where-Object { -not $следы[$в].Contains($_) })
        foreach ($p in $недостаёт) {
            $расхождений++; $hits.Add("парность`t$в`t$p`tврезка не долетела")
            Fail "врезка-парность: у '$в' НЕТ типа в составе '$p' (есть у других генерённых видов)"
        }
    }
    if ($расхождений -eq 0) { Ok "врезка-парность: тип-след всех $($своиВиды.Count) видов совпал ($($объединение.Count) составов)" }
}

# --- Вердикт ---
@("вид`tобъект`tисточник`tзаметка") + $hits | Set-Content -LiteralPath $HitsOut -Encoding UTF8
Write-Host ''
if ($ошибки.Count -eq 0) {
    Write-Host "=== ВЕРДИКТ G5: ЗЕЛЕНО (типозамкнуто по MDClasses) ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== ВЕРДИКТ G5: КРАСНО, проблем: $($ошибки.Count). Попадания: $HitsOut ===" -ForegroundColor Red
    exit 2
}
