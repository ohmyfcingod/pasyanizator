# Invoke-Пасьянс.ps1 — оркестратор конвейера Фазы 3 (такт 2: этапы 0–3 + G1, headless).
# Этапы 4–6 (clean EDT / накат / смоук) исполняются через EDT MCP отдельно — см. Фаза3-Пасьянс.md.
# Dry-run по умолчанию; -Apply — писать. Коды: 0 = зелено, 2 = красно.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Карта,
    [string[]]$Виды,
    [string]$Src = 'E:\1CRoot\EDTPasyanizator\До_КОРП_30_0407\src',
    [string]$RunId = (Get-Date -Format 'yyyy-MM-dd_HHmmss'),
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Пасьянс-Общее.ps1"
$отчёты = "$PSScriptRoot\Отчёты\$RunId"
New-Item -ItemType Directory -Force $отчёты | Out-Null
$лог = [System.Collections.Generic.List[string]]::new()
function Этап([string]$м) { $script:лог.Add($м); Write-Host "`n=== $м ===" -ForegroundColor Cyan }

# отбор видов — ДО G0: гейт получает фактический состав прогона для проверки
# межвидовых ссылок (ревью П3)
$к = Read-ПасьянсКарта $Карта
$именаКарты = @($к.виды | ForEach-Object { $_.справочник.имя })
# Опечатка в -Виды не должна молча сужать прогон (симметрично FAIL ВИДЫ смоука): заказанный
# вид, которого нет в карте, — стоп, а не тихое пересечение (пре-ревью такта 4).
if ($Виды) {
    $потеряно = @($Виды | Where-Object { $_ -notin $именаКарты })
    if ($потеряно) { Write-Host "Заказанные виды отсутствуют в карте: $($потеряно -join ', ')" -ForegroundColor Red; exit 2 }
}
$видыПрогона = @($именаКарты | Where-Object { -not $Виды -or $_ -in $Виды })
if ($видыПрогона.Count -eq 0) { Write-Host 'Ни один вид не отобран'; exit 2 }
# Неопознанный статус в КартаВрезок.tsv выпал бы из-под врезки и G1 без сигнала — стоп сразу.
$неизвестныеСтатусы = @(Import-Csv "$PSScriptRoot\КартаВрезок.tsv" -Delimiter "`t" |
    Where-Object { $_.статус -notin 'insert', 'verified', 'skip' })
if ($неизвестныеСтатусы) {
    $неизвестныеСтатусы | ForEach-Object { Write-Host "КартаВрезок: неизвестный статус '$($_.статус)' у $($_.файл)" -ForegroundColor Red }
    exit 2
}
Этап "Виды прогона: $($видыПрогона -join ', ') | Apply=$Apply | RunId=$RunId"

# Этап 0: G0
Этап "0. Test-Карта: $Карта"
& "$PSScriptRoot\Test-Карта.ps1" -Карта $Карта -Src $Src -ВидыПрогона $видыПрогона
if ($LASTEXITCODE -ne 0) { Write-Host 'G0 КРАСНО — стоп'; exit 2 }

# Этап 1: генерация видов
Этап '1. New-ВидПоЭталону'
& "$PSScriptRoot\New-ВидПоЭталону.ps1" -Карта $Карта -Виды $видыПрогона -Src $Src -Apply:$Apply
if ($LASTEXITCODE -ne 0) { Write-Host 'Этап 1 КРАСНО — стоп'; exit 2 }

# Этап 2: якорные врезки
Этап '2. Invoke-ЯкорнаяВрезка'
& "$PSScriptRoot\Invoke-ЯкорнаяВрезка.ps1" -Виды $видыПрогона -Src $Src -Apply:$Apply
if ($LASTEXITCODE -ne 0) { Write-Host 'Этап 2 КРАСНО — стоп'; exit 2 }

# Этап 3: bsl-предохранители
Этап '3. New-БслПредохранители'
& "$PSScriptRoot\New-БслПредохранители.ps1" -Src $Src -Apply:$Apply
if ($LASTEXITCODE -ne 0) { Write-Host 'Этап 3 КРАСНО — стоп'; exit 2 }

# G1: XML-парс тронутых/созданных .mdo
if ($Apply) {
    Этап 'G1. XML-валидность'
    $файлы = [System.Collections.Generic.List[string]]::new()
    $файлы.Add((Join-Path $Src 'Configuration\Configuration.mdo'))
    foreach ($в in $видыПрогона) { $файлы.Add((Join-Path $Src "Catalogs\$в\$в.mdo")) }
    $файлы.Add((Join-Path $Src 'CommonModules\Пасьянс_Типы\Пасьянс_Типы.mdo'))
    Import-Csv "$PSScriptRoot\КартаВрезок.tsv" -Delimiter "`t" |
        Where-Object { $_.статус -in 'insert','verified' } |
        ForEach-Object { $файлы.Add((Join-Path $Src $_.файл)) }
    $плохие = 0
    foreach ($ф in ($файлы | Sort-Object -Unique)) {
        if (-not (Test-Path $ф)) { continue }
        try {
            $x = [System.Xml.XmlDocument]::new()
            $x.Load($ф)
        } catch { Write-Host "  XML БИТ: $ф — $($_.Exception.Message)" -ForegroundColor Red; $плохие++ }
    }
    if ($плохие -gt 0) { Write-Host "G1 КРАСНО: битых XML $плохие"; exit 2 }
    Write-Host "  ok: XML целы ($(($файлы | Sort-Object -Unique).Count) файлов)"

    # незачищенный плейсхолдер шаблона ({{...}}) — валидный mixed content для XmlDocument,
    # но битый импорт для EDT: ловим грепом, XML-парс это не поймает
    $сОгрызками = 0
    foreach ($ф in ($файлы | Sort-Object -Unique)) {
        if (-not (Test-Path $ф)) { continue }
        if ((Get-Content $ф -Raw -Encoding utf8) -match '\{\{') {
            Write-Host "  ПЛЕЙСХОЛДЕР ОСТАЛСЯ: $ф" -ForegroundColor Red; $сОгрызками++
        }
    }
    if ($сОгрызками -gt 0) { Write-Host "G1 КРАСНО: файлов с {{...}} $сОгрызками"; exit 2 }
    Write-Host '  ok: огрызков шаблонов нет'
}

Этап "ГОТОВО. Этапы 0-3 зелёные. Дальше (MCP): clean_project -> get_project_errors (0 новых) -> update_database -> смоук"
$лог | Set-Content "$отчёты\Протокол.txt" -Encoding utf8
exit 0
