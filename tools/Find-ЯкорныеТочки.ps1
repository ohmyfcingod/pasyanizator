# Find-ЯкорныеТочки.ps1 — свип якорей типа ДокументыПредприятия по EDT-исходникам ДО3.
# Выход: КартаВрезок.tsv (объект | файл | вкус | статус | клинВставлен | примечание).
# Статусы: verified — точки, врезанные и проверенные спайком Фазы 2;
#          insert   — врезать (умолчание для всех найденных);
#          skip     — НЕ врезать (проставляется руками, причина обязательна).
# Повторный прогон НЕ перетирает ручные skip: существующий TSV читается, ручные статусы сохраняются.
# Требует pwsh 7 (UTF-8 по умолчанию).

[CmdletBinding()]
param(
    [string]$Src = 'E:\1CRoot\EDTPasyanizator\До_КОРП_30_0407\src',
    [string]$Out = "$PSScriptRoot\КартаВрезок.tsv"
)

$ErrorActionPreference = 'Stop'

# Вкусы якоря (критика №7: все три, не только CatalogRef)
$Вкусы = [ordered]@{
    'types-ref'    = '<types>CatalogRef.ДокументыПредприятия</types>'
    'types-object' = '<types>CatalogObject.ДокументыПредприятия</types>'
    'owners'       = '<owners>Catalog.ДокументыПредприятия</owners>'
}
$КлинМаркер = 'ПробныйДоговор'

# 10+ точек, врезанных и проверенных живьём в Фазе 2 (объект = относительный каталог)
$Verified = @(
    'DefinedTypes\ПредметДействия', 'DefinedTypes\ПредметДействияОбъект',
    'DefinedTypes\ПриложениеЗадач', 'DefinedTypes\ОбъектДоступа',
    'DefinedTypes\ОбъектУведомления', 'DefinedTypes\ИсточникБизнесСобытий',
    'Catalogs\ОбработкиОбъектов', 'Catalogs\ВизыСогласования',
    'BusinessProcesses\Согласование', 'BusinessProcesses\КомплексныйПроцесс',
    'Tasks\ЗадачаИсполнителя',
    'InformationRegisters\КешИнформацииОбОбъектах', 'InformationRegisters\МоиДокументы',
    'InformationRegisters\СвязиОбъектов'
)

# Автокандидаты на skip (решение — руками, скрипт только подсказывает)
$SkipПодсказка = 'ЭДО|МЭДО|Мэдо|XDTO|Миграци|1САрхив|ССТУ|Share|Удалить'

# Ручные статусы из прошлого прогона
$Ручные = @{}
if (Test-Path $Out) {
    Import-Csv $Out -Delimiter "`t" | ForEach-Object {
        if ($_.статус -eq 'skip') { $Ручные[$_.объект + '|' + $_.вкус] = $_ }
    }
}

$строки = [System.Collections.Generic.List[object]]::new()
Get-ChildItem $Src -Recurse -Filter '*.mdo' | ForEach-Object {
    $текст = [System.IO.File]::ReadAllText($_.FullName)
    $отн = $_.FullName.Substring($Src.Length + 1)
    $объект = Split-Path (Split-Path $отн -Parent) -Leaf
    $ветка = Split-Path (Split-Path $отн -Parent) -Parent
    $ключОбъекта = "$ветка\$объект"
    foreach ($вкус in $Вкусы.Keys) {
        $якорь = $Вкусы[$вкус]
        $n = ([regex]::Matches($текст, [regex]::Escape($якорь))).Count
        if ($n -eq 0) { continue }
        $клин = if ($текст.Contains($КлинМаркер)) { 'да' } else { '' }
        $статус = 'insert'
        $прим = "якорей=$n"
        if ($Verified -contains $ключОбъекта) { $статус = 'verified' }
        if ($ключОбъекта -match $SkipПодсказка) { $прим += '; кандидат-skip?' }
        $ручной = $Ручные[$ключОбъекта + '|' + $вкус]
        if ($ручной) { $статус = 'skip'; $прим = $ручной.примечание }
        $строки.Add([pscustomobject]@{
            объект = $ключОбъекта; файл = $отн; вкус = $вкус
            статус = $статус; клинВставлен = $клин; примечание = $прим
        })
    }
}

$строки | Sort-Object статус, объект |
    Export-Csv $Out -Delimiter "`t" -NoTypeInformation -Encoding utf8BOM

$sum = $строки | Group-Object статус | ForEach-Object { "$($_.Name)=$($_.Count)" }
$клинОк = ($строки | Where-Object { $_.статус -eq 'verified' -and -not $_.клинВставлен })
Write-Host "КартаВрезок: $($строки.Count) точек ($($sum -join ', ')) -> $Out"
if ($клинОк) {
    Write-Host "ВНИМАНИЕ: verified-точки БЕЗ клина (расхождение со спайком):" -ForegroundColor Yellow
    $клинОк | ForEach-Object { Write-Host "  $($_.объект) [$($_.вкус)]" }
    exit 2
}
exit 0
