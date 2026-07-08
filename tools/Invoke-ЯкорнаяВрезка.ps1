# Invoke-ЯкорнаяВрезка.ps1 — этап 2 конвейера: врезка типов новых видов во все точки
# КартаВрезок.tsv (статусы insert/verified; skip не трогаем). Идемпотентно: вставка
# отсутствует только внутри СВОЕГО блока <type>…</type> (у СвязиОбъектов два измерения —
# проверка по-блочно, не по-файлово). Dry-run по умолчанию.

[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]]$Виды,
    [string]$Src = 'E:\1CRoot\EDTPasyanizator\До_КОРП_30_0407\src',
    [string]$КартаВрезок = "$PSScriptRoot\КартаВрезок.tsv",
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Пасьянс-Общее.ps1"

$Якоря = @{
    'types-ref'    = '<types>CatalogRef.ДокументыПредприятия</types>'
    'types-object' = '<types>CatalogObject.ДокументыПредприятия</types>'
    'owners'       = '<owners>Catalog.ДокументыПредприятия</owners>'
}
function Вставка([string]$Вкус, [string]$Вид) {
    switch ($Вкус) {
        'types-ref'    { "<types>CatalogRef.$Вид</types>" }
        'types-object' { "<types>CatalogObject.$Вид</types>" }
        'owners'       { "<owners>Catalog.$Вид</owners>" }
    }
}

$точки = Import-Csv $КартаВрезок -Delimiter "`t" | Where-Object { $_.статус -in 'insert','verified' }
$итоги = @{ вставлено = 0; ужеБыло = 0; файлов = 0; якорейНеНайдено = 0; файловНет = 0 }
$поФайлам = $точки | Group-Object файл

foreach ($группа in $поФайлам) {
    $путь = Join-Path $Src $группа.Name
    if (-not (Test-Path $путь)) {
        # молчаливый пропуск точки = неврезанный тип при зелёном exit — класс «предохранитель №4»
        Write-Host "  ФАЙЛ НЕ НАЙДЕН: $($группа.Name) (точек: $($группа.Group.Count))" -ForegroundColor Red
        $итоги.файловНет++
        continue
    }
    $ф = Read-Текст $путь
    $строки = [System.Collections.Generic.List[string]]::new()
    $строки.AddRange([string[]]($ф.Текст -split "`n"))
    $менялся = $false

    foreach ($точка in $группа.Group) {
        $якорь = $Якоря[$точка.вкус]
        $якорейВТочке = 0
        $i = 0
        while ($i -lt $строки.Count) {
            if ($строки[$i].Contains($якорь)) {
                $якорейВТочке++
                $отступ = $строки[$i].Substring(0, $строки[$i].Length - $строки[$i].TrimStart().Length)
                # граница блока: для types-вкусов — до </type>; для owners — весь файл
                $конецБлока = $строки.Count - 1
                if ($точка.вкус -ne 'owners') {
                    for ($j = $i + 1; $j -lt $строки.Count; $j++) {
                        if ($строки[$j].Contains('</type>')) { $конецБлока = $j; break }
                    }
                }
                $начало = $(if ($точка.вкус -eq 'owners') { 0 } else { $i })
                foreach ($вид in $Виды) {
                    $вставка = Вставка $точка.вкус $вид
                    $есть = $false
                    for ($j = $начало; $j -le $конецБлока; $j++) {
                        if ($строки[$j].Contains($вставка)) { $есть = $true; break }
                    }
                    if ($есть) { $итоги.ужеБыло++ }
                    else {
                        $строки.Insert($i + 1, "$отступ$вставка")
                        $конецБлока++
                        $итоги.вставлено++
                        $менялся = $true
                    }
                }
            }
            $i++
        }
        if ($якорейВТочке -eq 0) {
            # якорь исчез из файла (обновление ДО3, ручная правка, переформатирование) —
            # тип НЕ врезан, EDT это не заметит (отсутствие в составе — не ошибка компиляции)
            Write-Host "  ЯКОРЬ НЕ НАЙДЕН: $($точка.файл) [$($точка.вкус)]" -ForegroundColor Red
            $итоги.якорейНеНайдено++
        }
    }

    if ($менялся) {
        $итоги.файлов++
        if ($Apply) { Write-Текст $путь ($строки -join "`n") $ф.BOM }
    }
}

Write-Host "ЯкорнаяВрезка [$($Виды -join ',')]: вставлено=$($итоги.вставлено), уже-было=$($итоги.ужеБыло), файлов затронуто=$($итоги.файлов), якорей не найдено=$($итоги.якорейНеНайдено), файлов нет=$($итоги.файловНет)"
if (-not $Apply) { Write-Host 'DRY-RUN: файлы не писались (добавь -Apply)' -ForegroundColor Yellow }
if ($итоги.якорейНеНайдено -gt 0 -or $итоги.файловНет -gt 0) {
    Write-Host 'КРАСНО: есть точки карты без якоря/файла — карту врезок надо актуализировать' -ForegroundColor Red
    exit 2
}
exit 0
