# Invoke-НормализацияEOL.ps1 — лечебный проход П1.4: приводит к CRLF файлы, испорченные
# LF-вставками врезок (mixed-EOL), по периметру конвейера: точки КартаВрезок.tsv +
# сгенерённые виды + Пасьянс_Типы + маркер-блочные .bsl + Configuration.mdo.
# Идемпотентен: повторный прогон = 0 изменённых. Гейт: git diff --ignore-cr-at-eol ПУСТ.

[CmdletBinding()]
param(
    [string]$Src = 'E:\1CRoot\EDTPasyanizator\До_КОРП_30_0407\src',
    [string]$КартаВрезок = "$PSScriptRoot\КартаВрезок.tsv",
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Пасьянс-Общее.ps1"

$файлы = [System.Collections.Generic.List[string]]::new()
$точкиВрезок = Import-Csv $КартаВрезок -Delimiter "`t"
# Неопознанный статус выпал бы из лечения (и остался бы mixed-EOL) без сигнала — стоп.
$неизв = @($точкиВрезок | Where-Object { $_.статус -notin 'insert', 'verified', 'skip' })
if ($неизв) { $неизв | ForEach-Object { Write-Host "  КартаВрезок: неизвестный статус '$($_.статус)' у $($_.файл)" -ForegroundColor Red }; exit 2 }
$точкиВрезок | Where-Object { $_.статус -in 'insert', 'verified' } |
    ForEach-Object { $файлы.Add((Join-Path $Src $_.файл)) }
Get-ChildItem (Join-Path $Src 'Catalogs') -Directory | Where-Object {
    $mdo = Join-Path $_.FullName "$($_.Name).mdo"
    (Test-Path $mdo) -and ([System.IO.File]::ReadAllText($mdo).Contains('Пасьянизатор из вида'))
} | ForEach-Object { Get-ChildItem $_.FullName -Recurse -File | ForEach-Object { $файлы.Add($_.FullName) } }
$файлы.Add((Join-Path $Src 'CommonModules\Пасьянс_Типы\Пасьянс_Типы.mdo'))
$файлы.Add((Join-Path $Src 'CommonModules\Пасьянс_Типы\Module.bsl'))
$файлы.Add((Join-Path $Src 'CommonModules\ДействияСервер\Module.bsl'))
$файлы.Add((Join-Path $Src 'Enums\ТипыПриложенийЗадач\ManagerModule.bsl'))
$файлы.Add((Join-Path $Src 'Configuration\Configuration.mdo'))

$вылечено = 0
$чисто = 0
foreach ($путь in ($файлы | Sort-Object -Unique)) {
    if (-not (Test-Path $путь)) { continue }
    $ф = Read-Текст $путь
    if ($ф.Текст -match "(?<!`r)`n") {
        if ($Apply) { Write-Текст $путь $ф.Текст $ф.BOM }  # Write-Текст сам нормализует
        Write-Host "  CRLF <- $путь"
        $вылечено++
    } else { $чисто++ }
}
Write-Host "НормализацияEOL: вылечено $вылечено, уже чистых $чисто$(if (-not $Apply) {' (DRY-RUN)'})"
exit 0
