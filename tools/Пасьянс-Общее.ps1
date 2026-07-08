# Пасьянс-Общее.ps1 — dot-source хелперы конвейера (pwsh 7).

# Детерминированный UUID из строкового сида (SHA1). Сеять от uuid'ов (вида/свойства),
# НЕ от имён — переименование не должно пересоздавать колонку (критика №27 плана).
function New-ДетерминированныйUuid([string]$Сид) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try {
        $b = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Сид))
    } finally { $sha.Dispose() }
    # ЗАР: из-за little-endian раскладки [guid]::new(byte[]) в первых трёх группах маска по b[6]
    # НЕ попадает в строковый ниббл «версии» — UUID детерминированный и стабильный, но НЕ строго
    # RFC-v4. Менять раскладку НЕЛЬЗЯ: пересеет все уже сгенерённые uuid (сломает идемпотентность
    # против живых конфигураций). Внешним валидаторам версию не обещаем.
    $b[6] = ($b[6] -band 0x0f) -bor 0x40
    $b[8] = ($b[8] -band 0x3f) -bor 0x80
    $g = [byte[]]::new(16)
    [Array]::Copy($b, $g, 16)
    ([guid]::new($g)).ToString()
}

function Read-ПасьянсКарта([string]$Путь) {
    Get-Content $Путь -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
}

# Чтение/запись текста с сохранением BOM-состояния файла (не ломаем то, что было).
function Read-Текст([string]$Путь) {
    $байты = [System.IO.File]::ReadAllBytes($Путь)
    $bom = $байты.Length -ge 3 -and $байты[0] -eq 0xEF -and $байты[1] -eq 0xBB -and $байты[2] -eq 0xBF
    [pscustomobject]@{
        Текст = [System.Text.Encoding]::UTF8.GetString($байты, $(if ($bom) {3} else {0}), $байты.Length - $(if ($bom) {3} else {0}))
        BOM   = $bom
    }
}

function Write-Текст([string]$Путь, [string]$Текст, [bool]$BOM) {
    # ЕДИНЫЙ EOL НА ВЫХОДЕ (такт 4, П1.4): всё, что пишет конвейер, — CRLF (канон 1С-мира).
    # Входы (.tpl) остаются LF (.gitattributes eol=lf) — зачистки плейсхолдеров LF-зависимы;
    # канонизация ВЫХОДА чинит mixed-EOL от вставок и делает диффы обновления релиза чистыми.
    $Текст = [regex]::Replace($Текст, "\r?\n", "`r`n")
    $enc = [System.Text.UTF8Encoding]::new($BOM)
    [System.IO.File]::WriteAllText($Путь, $Текст, $enc)
}
