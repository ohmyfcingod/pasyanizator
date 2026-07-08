# Test-ЧистотаПоставки.ps1 — ГЕЙТ поставки (такт 6): в чистой поставке НЕТ тест-харнесса.
# Стенд разработки несёт временный обвес (экстрактор/смоук-обработки, драйвер-врезки самопрогона,
# посевные ПАСЬЯНС-ТЕСТ виды) — он НЕ должен уехать в боевую поставку. Гейт краснеет, если харнесс
# на месте; зеленеет на очищенной поставке (после Remove-харнесса / сборки чистого .cf).
#
# ОСТАЁТСЯ в поставке (НЕ харнесс, гейт их НЕ трогает): модуль Пасьянс_Типы + маркер-блоки
# ПАСЬЯНС-ВРЕЗКА (предохранители, нужны сгенерённым видам), сами Catalog.<Вид> и якорные врезки типов.
#
# Коды: 0 = чисто (поставка без харнесса), 2 = харнесс на месте, 1 = ошибка. Требует pwsh 7.

[CmdletBinding()]
param(
    [string]$Src = 'E:\1CRoot\EDTPasyanizator\До_КОРП_30_0407\src'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Src)) { Write-Host "Нет каталога: $Src" -ForegroundColor Red; exit 1 }
$ошибки = [System.Collections.Generic.List[string]]::new()
function Fail([string]$м) { $script:ошибки.Add($м); Write-Host "  FAIL $м" -ForegroundColor Red }
function Ok([string]$м) { Write-Host "  ok   $м" -ForegroundColor Green }

Write-Host "=== Test-ЧистотаПоставки: $Src ==="

function ФайлыСМаркером([string]$Маркер) {
    $найдено = [System.Collections.Generic.List[string]]::new()
    foreach ($f in (Get-ChildItem -LiteralPath $Src -Recurse -Include *.bsl, *.mdo, *.xml -File -ErrorAction SilentlyContinue)) {
        try { if ([System.IO.File]::ReadAllText($f.FullName).Contains($Маркер)) { $найдено.Add($f.FullName.Substring($Src.Length).TrimStart('\', '/')) } } catch {}
    }
    return $найдено
}

# 1. Маркеры временного кода харнесса
$темпМаркеры = @('ПАСЬЯНИЗАТОР-ВРЕМЕННО', 'ПАСЬЯНС-СМОУК', 'ПАСЬЯНС-ТЕСТ', 'ПасьянизаторЗапустить')
foreach ($м in $темпМаркеры) {
    $ф = ФайлыСМаркером $м
    if ($ф.Count -gt 0) { Fail "маркер харнесса '$м' в поставке ($($ф.Count) файлов): $(($ф | Select-Object -First 3) -join '; ')$(if ($ф.Count -gt 3) {' …'})" }
    else { Ok "маркера '$м' нет" }
}

# 2. Временные обработки харнесса (экстрактор/смоук — ПАСЬЯНИЗАТОР-ВРЕМЕННО по паспорту)
$темпОбработки = @('ПасьянизаторЭкстрактор', 'ПасьянизаторСмоук')
foreach ($дп in $темпОбработки) {
    $путь = Join-Path $Src "DataProcessors\$дп"
    if (Test-Path -LiteralPath $путь) { Fail "тест-обработка DataProcessor.$дп в поставке" }
    else { Ok "DataProcessor.$дп отсутствует" }
}

# 3. Посевные ПАСЬЯНС-ТЕСТ виды (тестовые данные, не боевая поставка)
$тестВиды = @(Get-ChildItem -LiteralPath (Join-Path $Src 'Catalogs') -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'ПАСЬЯНСТЕСТ*' } | ForEach-Object Name)
if ($тестВиды.Count -gt 0) { Fail "посевные тест-виды в поставке ($($тестВиды.Count)): $($тестВиды -join ', ')" }
else { Ok "посевных ПАСЬЯНСТЕСТ-видов нет" }

# Вердикт
Write-Host ''
if ($ошибки.Count -eq 0) {
    Write-Host "=== ВЕРДИКТ: ЗЕЛЕНО (поставка чистая, харнесса нет) ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== ВЕРДИКТ: КРАСНО, харнесс на месте: $($ошибки.Count) — поставку так не отдавать ===" -ForegroundColor Red
    exit 2
}
