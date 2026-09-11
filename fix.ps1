<#
    RuRBW Service Restorer
    Включает обратно системные службы Windows, которые вырубают «твикеры»,
    из-за чего на ScreenShare прилетает бан за Disabled Services.

    Проект : Russian Ranked Bedwars, rurbw.pro
    Автор  : @slurov
    Версия : 1.0.1
    Лицензия: MIT

    Запуск одной строкой в cmd:
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/slurov/rurbw-service-restorer/v1.0.1/fix.ps1 | iex"

    Запуск скачанного файла - из cmd, открытого от имени администратора:
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (Get-Content .\fix.ps1 -Raw -Encoding UTF8)"

    Если проверяешь код перед запуском, смотри сюда. Во всём файле ровно семь
    команд, способных что-то изменить, найди их поиском и убедись, что других нет:

      Set-Service -StartupType | Repair-Service, включает службу
      sc.exe config start=     | Repair-Service, то же для драйверов
      Set-ItemProperty 'Start' | Repair-Service, запасной путь для драйверов
      Start-Service            | Repair-Service, запускает службу
      Set-Content              | Export-Report, отчёт на рабочий стол
      shutdown.exe /r /t 10    | Invoke-Reboot, только по нажатию кнопки
      shutdown.exe /a          | отмена той же перезагрузки, по кнопке

    Первые четыре живут только внутри Repair-Service, и перед ними стоит
    предохранитель: тип запуска обязан быть одним из четырёх «включающих»,
    имя службы - из таблицы $SERVICES. Значения «отключить» нет ни в таблице,
    ни в функциях перевода, записать его нечем. Stop-Service, Remove-Item,
    reg delete и taskkill в файле не встречаются ни разу.
#>

# Скрипт запускается через `irm ... | iex`, файла на диске нет.
# Поэтому здесь нет param(), #Requires, $PSScriptRoot и относительных путей.
#
# Файл сохранён в UTF-8 БЕЗ BOM, и добавлять BOM нельзя. irm превращает BOM
# в невидимый символ U+FEFF в начале текста, он прилипает к «<#» в первой
# строке, шапка перестаёт быть комментарием, и iex пытается выполнить её как код.
# Кириллица без BOM не ломается: GitHub отдаёт файл с charset=utf-8.
# По той же причине нельзя запускать файл через -File: Windows PowerShell 5.1
# прочитает его в кодировке системы. Для запуска с диска - Get-Content -Encoding UTF8.

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# --- Константы ---
# По этому адресу скрипт перекачивает сам себя при перезапуске от администратора,
# поэтому он указывает на тег релиза, а не на ветку main: содержимое ветки меняется,
# и однажды от администратора выполнился бы не тот код, который игрок читал.
# Хеш коммита тут не подходит - файл не может содержать хеш коммита, в котором
# сам лежит. Чтобы тег нельзя было передвинуть, в репозитории включена защита тегов.
$SCRIPT_URL     = 'https://raw.githubusercontent.com/slurov/rurbw-service-restorer/v1.0.1/fix.ps1'
$SCRIPT_VERSION = 'v1.0.1'
$DISCORD_URL    = 'https://discord.gg/rurbw'

# Палитра тёмной темы.
$CLR = @{
    Bg         = '#2B2D31'   # фон окна
    Panel      = '#313338'   # карточки и таблица
    PanelHead  = '#2F3136'   # шапка таблицы
    Chrome     = '#1E1F22'   # строка состояния
    Border     = '#26272B'
    Border2    = '#232428'
    Line       = '#2B2D31'   # разделители строк таблицы
    Text       = '#F2F3F5'
    Text2      = '#DBDEE1'
    Text3      = '#B5BAC1'
    Muted      = '#949BA4'
    Muted2     = '#6D7278'
    Muted3     = '#7C8189'
    Head       = '#8B9199'
    Accent     = '#A8283A'   # фирменный красный RuRBW
    AccentFg   = '#FBEFF1'
    AccentBd   = '#B94255'
    Green      = '#3BA55D'
    Red        = '#ED4245'
    Amber      = '#E8A33D'
    GreenText  = '#79C48F'
    RedText    = '#E8747A'
    AmberText  = '#D9A86A'
    Btn        = '#3A3C42'
    BtnBorder  = '#45474D'
    BtnHover   = '#45474D'
    BtnOffBg   = '#35373D'
    BtnOffFg   = '#6D7278'
    BtnOffBd   = '#3F4147'
    BoxBorder  = '#7B7F86'
    BoxBorder2 = '#42444A'
    RowProblem = '#423138'   # красная подсветка строки
    RowWarn    = '#423D38'   # жёлтая подсветка строки
    RowMissing = '#34363B'   # серая подсветка строки
    RowSel     = '#3A3C42'
    BadgeBg    = '#2F3A33'
    BadgeBd    = '#3A4A3F'
    ModalBd    = '#1C1D20'
}

# --- Таблица служб ---
# Key         - системное имя службы (как в services.msc / sc.exe)
# AltNames    - другие имена этой же службы в старых сборках Windows
# DisplayName - как показываем игроку
# Target      - заводской тип запуска: Automatic / AutomaticDelayed / Manual / System
# TargetWin10 - если у Windows 10 заводское значение другое (см. комментарий у записи)
# Kind        - 'Service' (обычная служба) или 'Driver' (kernel-драйвер)
# Critical    - не трогаем вообще: ни тип запуска, ни запуск. Слишком опасно
# Description - объяснение для игрока, который не знает, что такое служба
$SERVICES = @(
    @{ Key='SysMain'; AltNames=@('SuperFetch'); DisplayName='SysMain'
       Target='Automatic'; Kind='Service'; Critical=$false
       Description='Ускоряет запуск программ и ведёт учёт их использования' }

    # Windows 11: «Автоматически (отложенный запуск)» - проверено на живой Windows 11
    # (сборка 26200): StartMode=Auto, DelayedAutoStart=True.
    # Windows 10: Manual - заводское значение, «усиливать» его не нужно
    # (batcmd.com/windows/10/services/pcasvc).
    @{ Key='PcaSvc'; AltNames=@(); DisplayName='Помощник по совместимости программ'
       Target='AutomaticDelayed'; TargetWin10='Manual'; Kind='Service'; Critical=$false
       Description='Записывает, какие программы запускались на компьютере' }

    @{ Key='DPS'; AltNames=@(); DisplayName='Служба политики диагностики'
       Target='Automatic'; Kind='Service'; Critical=$false
       Description='Диагностика Windows, нужна для работы других журналов' }

    # Системная, но не критическая для загрузки: в отличие от DcomLaunch и PlugPlay,
    # смена её типа запуска Windows не сломает. А без журнала событий проверяющему
    # на ScreenShare смотреть не во что, так что чинить её нужно в первую очередь.
    @{ Key='EventLog'; AltNames=@(); DisplayName='Журнал событий Windows'
       Target='Automatic'; Kind='Service'; Critical=$false
       Description='Журнал событий Windows - главный источник истории системы' }

    @{ Key='Schedule'; AltNames=@(); DisplayName='Планировщик заданий'
       Target='Automatic'; Kind='Service'; Critical=$false
       Description='Планировщик заданий Windows' }

    # Заводское значение - «Автоматически (отложенный запуск)».
    # Set-Service в PowerShell 5.1 не умеет delayed, поэтому чиним через sc.exe.
    @{ Key='WSearch'; AltNames=@(); DisplayName='Поиск Windows'
       Target='AutomaticDelayed'; Kind='Service'; Critical=$false
       Description='Поиск Windows, ведёт индекс файлов на диске' }

    @{ Key='Appinfo'; AltNames=@(); DisplayName='Сведения о приложении'
       Target='Manual'; Kind='Service'; Critical=$false
       Description='Отвечает за запуск программ от имени администратора' }

    @{ Key='SSDPSRV'; AltNames=@(); DisplayName='Обнаружение SSDP'
       Target='Manual'; Kind='Service'; Critical=$false
       Description='Обнаружение устройств в локальной сети' }

    # Заводское значение - «Автоматически (отложенный запуск)»: проверено на живой
    # Windows 11 (сборка 26200), StartMode=Auto, DelayedAutoStart=True.
    @{ Key='CDPSvc'; AltNames=@(); DisplayName='Платформа подключённых устройств'
       Target='AutomaticDelayed'; Kind='Service'; Critical=$false
       Description='Платформа подключённых устройств' }

    @{ Key='DiagTrack'; AltNames=@(); DisplayName='Телеметрия и диагностика'
       Target='Automatic'; Kind='Service'; Critical=$false
       Description='Телеметрия и диагностика Windows' }

    @{ Key='WdiServiceHost'; AltNames=@(); DisplayName='Узел службы диагностики'
       Target='Manual'; Kind='Service'; Critical=$false
       Description='Диагностический узел службы' }

    @{ Key='WdiSystemHost'; AltNames=@(); DisplayName='Узел системы диагностики'
       Target='Manual'; Kind='Service'; Critical=$false
       Description='Диагностический узел системы' }

    @{ Key='DcomLaunch'; AltNames=@(); DisplayName='Модуль запуска процессов DCOM'
       Target='Automatic'; Kind='Service'; Critical=$true
       Description='Критическая системная служба, менять нельзя' }

    @{ Key='PlugPlay'; AltNames=@(); DisplayName='Plug and Play'
       Target='Manual'; Kind='Service'; Critical=$true
       Description='Критическая системная служба, менять нельзя' }

    # bam.sys и dam.sys - это kernel-драйверы, а не обычные службы.
    # Get-Service показывает их некорректно (отсюда «Bam - Unknown» в чужих утилитах),
    # Set-Service на них не работает: состояние читаем из реестра, чиним через sc.exe.
    #
    # ЗАВОДСКОЕ ЗНАЧЕНИЕ Start = 1 (SERVICE_SYSTEM_START). Проверено по трём источникам:
    #   1) batcmd.com/windows/10/services/bam и /dam - «System» для всех версий
    #      и редакций Windows 10 (bam: 1709...22H2, dam: 1507...22H2);
    #   2) revertservice.com/10/bam и revertservice.com/11/bam - команда восстановления
    #      заводского значения указана как `sc config bam start= system`;
    #   3) реальная Windows 11 (сборка 26200): dam = 1 в реестре.
    # Значения Start: 0=Boot, 1=System, 2=Automatic, 3=Manual, 4=Disabled.
    @{ Key='bam'; AltNames=@(); DisplayName='Активность приложений (BAM)'
       Target='System'; Kind='Driver'; Critical=$false
       Description='Записывает, когда и какие программы запускались' }

    @{ Key='dam'; AltNames=@(); DisplayName='Активность рабочего стола (DAM)'
       Target='System'; Kind='Driver'; Critical=$false
       Description='Следит за активностью программ в спящем режиме' }
)
# В списке сознательно НЕТ:
#   Csrss         - это системный процесс, а не служба, включить/отключить нельзя;
#   SearchIndexer - это процесс службы WSearch, отдельной службы с таким именем нет.

# Общее состояние приложения. Всё изменяемое живёт в одной хеш-таблице,
# чтобы обработчики событий видели те же самые данные.
$App = @{
    IsAdmin    = $false
    States     = @()      # текущие состояния служб
    Baseline   = @{}      # снимок «было» на момент ПЕРВОГО сканирования (пруф для проверяющего)
    Running    = $false   # идёт исправление
    Fixed      = 0
    Failed     = 0
    Errors     = @()
    Notes      = @()      # некритичные замечания по ходу исправления
    NeedReboot = $false
    Progress   = @{ Index = 0; Total = 0; Line = '' }
    Populating = $false
    Suppress   = $false
    UI         = @{}
}

# --- Права администратора ---
# Запущены ли мы от имени администратора.
function Test-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Перезапуск самого себя от имени администратора.
#
# ПОЧЕМУ ПЕРЕКАЧИВАЕМ СКРИПТ, А НЕ ПЕРЕДАЁМ СОБСТВЕННЫЙ ТЕКСТ:
# скрипт пришёл через `irm | iex`, файла на диске нет. Под iex $MyInvocation
# указывает не на наш код, а на вызывающий (проверено: возвращает чужой текст
# и чужую длину), а записать собственный исходник в переменную в начале файла
# нельзя - файл не может целиком содержать сам себя.
# Поэтому единственный надёжный источник - тот же адрес, откуда игрок запустил
# скрипт. Ссылка ведёт на тег релиза, а не на ветку, поэтому админ-копия
# выполняет тот же код, который игрок прочитал
# на GitHub. Загружается ровно один файл - этот же самый; ничего не отправляется.
function Invoke-Elevate {
    # Если между запуском и подтверждением UAC пропал интернет, повторная
    # загрузка упадёт, консоль мгновенно закроется, и игрок останется вообще
    # без окна. Поэтому в админ-копии ловим ошибку и показываем её человеку.
    $command = @"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod -Uri '$SCRIPT_URL' | Invoke-Expression
}
catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        'Не удалось загрузить утилиту: ' + `$_.Exception.Message + [Environment]::NewLine + [Environment]::NewLine + 'Проверь интернет и запусти команду заново.',
        'RuRBW Service Restorer') | Out-Null
}
"@
    # -EncodedCommand принимает Base64 от Unicode-байт: так текст переживает
    # любые кавычки и кириллицу в командной строке.
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
        ) | Out-Null
        return $true
    }
    catch {
        # Сюда попадаем, когда игрок нажал «Нет» в окне контроля учётных записей.
        return $false
    }
}

# --- Мелкие помощники ---
function Get-Color { param([string]$Hex) return [System.Drawing.ColorTranslator]::FromHtml($Hex) }

# Числовое значение Start из реестра -> человекочитаемое имя.
function ConvertTo-StartupName {
    param([int]$Start)
    switch ($Start) {
        0 { 'Boot' }
        1 { 'System' }
        2 { 'Automatic' }
        3 { 'Manual' }
        4 { 'Disabled' }
        default { 'Unknown' }
    }
}

# Имя типа запуска -> числовое значение для реестра.
#
# Значений «Disabled» (4) и «Boot» (0) здесь нет сознательно: функция работает
# только на запись, а утилита не имеет права ничего отключать. Раз значения нет
# в таблице, записать его не получится даже при ошибке в остальном коде.
# Для чтения есть ConvertTo-StartupName, там все значения на месте.
function ConvertFrom-StartupName {
    param([string]$Name)
    switch ($Name) {
        'System'           { 1 }
        'Automatic'        { 2 }
        'AutomaticDelayed' { 2 }
        'Manual'           { 3 }
        default            { -1 }   # неизвестное значение - вызывающий обязан отказаться
    }
}

# Имя типа запуска -> значение для `sc.exe config <служба> start= <...>`.
# Здесь тоже нет «disabled» - по той же причине, что и выше.
function ConvertTo-ScStartValue {
    param([string]$Name)
    switch ($Name) {
        'System'           { 'system' }
        'Automatic'        { 'auto' }
        'AutomaticDelayed' { 'delayed-auto' }
        'Manual'           { 'demand' }
        default            { '' }   # неизвестное значение - вызывающий обязан отказаться
    }
}

# Тип запуска по-русски (для таблицы и отчёта).
function Get-StartupRu {
    param([string]$Name)
    switch ($Name) {
        'Boot'             { 'Загрузочный' }
        'System'           { 'Системный' }
        'Automatic'        { 'Автоматически' }
        'AutomaticDelayed' { 'Авто (отлож.)' }
        'Manual'           { 'Вручную' }
        'Disabled'         { 'Отключён' }
        'None'             { '—' }
        default            { 'Неизвестно' }
    }
}

# Состояние службы по-русски.
function Get-StatusRu {
    param([string]$Status)
    switch ($Status) {
        'Running'  { 'Работает' }
        'Stopped'  { 'Остановлена' }
        'None'     { '—' }
        default    { $Status }
    }
}

# Windows 11 отличается от Windows 10 номером сборки (22000 и выше).
# Номер берём из реестра: [Environment]::OSVersion в .NET Framework подвержен
# слоям совместимости и на приложении без манифеста может соврать (вернуть 6.2).
# Реестр такому не подвержен; OSVersion остаётся запасным вариантом.
function Test-Windows11 {
    try {
        $build = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).CurrentBuildNumber
        if ($build) { return ([int]$build -ge 22000) }
    }
    catch { }
    return ([Environment]::OSVersion.Version.Build -ge 22000)
}

# Строка с версией Windows для отчёта.
function Get-WindowsInfo {
    try {
        $os      = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $display = ''
        try {
            $cv = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
            if ($cv.DisplayVersion) { $display = " $($cv.DisplayVersion)" }
            elseif ($cv.ReleaseId)  { $display = " $($cv.ReleaseId)" }
        } catch { }
        return "$($os.Caption)$display (сборка $($os.BuildNumber))"
    }
    catch {
        return [Environment]::OSVersion.VersionString
    }
}

# --- Сбор состояния служб ---
# Состояние одной службы из таблицы $SERVICES.
# $CimIndex    - словарь имя -> Win32_Service (обычные службы)
# $DriverIndex - словарь имя -> Win32_SystemDriver (kernel-драйверы bam/dam)
function Get-ServiceState {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Definition,
        [hashtable]$CimIndex    = @{},
        [hashtable]$DriverIndex = @{}
    )

    # Заводское значение у Windows 10 и Windows 11 может отличаться.
    $target = $Definition.Target
    if ($Definition.ContainsKey('TargetWin10') -and -not (Test-Windows11)) {
        $target = $Definition.TargetWin10
    }

    $state = [PSCustomObject]@{
        Key            = $Definition.Key
        Name           = $Definition.Key
        DisplayName    = $Definition.DisplayName
        Description    = $Definition.Description
        Kind           = $Definition.Kind
        Critical       = [bool]$Definition.Critical
        Target         = $target
        Exists         = $false
        CurrentStatus  = 'None'    # Running / Stopped / None
        CurrentStartup = 'None'    # Automatic / AutomaticDelayed / Manual / Disabled / System / None
        IsProblem      = $false
        ProblemKind    = 'None'    # Startup (красная) / Stopped (жёлтая) / None
        CanFix         = $false
        Hint           = ''        # что делать, если утилита чинить не вправе
    }

    # 1. Ищем службу под основным именем и под старыми именами.
    #    Пример: в ранних сборках Windows 10 SysMain называлась SuperFetch.
    $found = $null
    foreach ($name in (@($Definition.Key) + @($Definition.AltNames))) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if (Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$name") { $found = $name; break }
    }
    # Службы может не быть вообще (например, DiagTrack вырезан кастомной сборкой).
    if (-not $found) { return $state }

    $state.Name   = $found
    $state.Exists = $true
    $regPath      = "HKLM:\SYSTEM\CurrentControlSet\Services\$found"

    # 2. Тип запуска из реестра: значение Start (0=Boot, 1=System, 2=Automatic,
    #    3=Manual, 4=Disabled). Для драйверов это ЕДИНСТВЕННЫЙ надёжный источник.
    $startValue = -1
    $delayed    = $false
    try {
        $reg = Get-ItemProperty -LiteralPath $regPath -ErrorAction Stop
        if ($null -ne $reg.Start) { $startValue = [int]$reg.Start }
        if ($reg.DelayedAutostart -eq 1) { $delayed = $true }
    }
    catch { }

    if ($Definition.Kind -eq 'Driver') {
        # bam / dam: Set-Service и Get-Service с ними не работают.
        $state.CurrentStartup = ConvertTo-StartupName $startValue
        $drv = $null
        if ($DriverIndex.ContainsKey($found.ToLower())) { $drv = $DriverIndex[$found.ToLower()] }
        if ($drv) {
            if ($drv.State -eq 'Running') { $state.CurrentStatus = 'Running' }
            elseif ($drv.State -eq 'Stopped') { $state.CurrentStatus = 'Stopped' }
            else { $state.CurrentStatus = [string]$drv.State }
        }
    }
    else {
        # Обычные службы: Get-Service в PowerShell 5.1 не отдаёт тип запуска,
        # поэтому берём StartMode из Win32_Service, а реестр оставляем как запасной путь.
        $cim = $null
        if ($CimIndex.ContainsKey($found.ToLower())) { $cim = $CimIndex[$found.ToLower()] }
        if ($cim) {
            $state.CurrentStartup = switch ([string]$cim.StartMode) {
                'Auto'     { if ($delayed) { 'AutomaticDelayed' } else { 'Automatic' } }
                'Manual'   { 'Manual' }
                'Disabled' { 'Disabled' }
                'Boot'     { 'Boot' }
                'System'   { 'System' }
                default    { ConvertTo-StartupName $startValue }
            }
            if ($cim.State -eq 'Running') { $state.CurrentStatus = 'Running' }
            elseif ($cim.State -eq 'Stopped') { $state.CurrentStatus = 'Stopped' }
            else { $state.CurrentStatus = [string]$cim.State }
        }
        else {
            $fromReg = ConvertTo-StartupName $startValue
            if ($fromReg -eq 'Automatic' -and $delayed) { $fromReg = 'AutomaticDelayed' }
            $state.CurrentStartup = $fromReg
            try { $state.CurrentStatus = [string](Get-Service -Name $found -ErrorAction Stop).Status }
            catch { $state.CurrentStatus = 'None' }
        }
    }

    # 3. Что считаем проблемой:
    #    * «Отключён» - всегда проблема: служба не запустится даже вручную;
    #    * тип запуска слабее заводского (Вручную там, где должно быть Автоматически);
    #    * служба обязана работать постоянно, но остановлена.
    #    Тип запуска СИЛЬНЕЕ заводского (Автоматически там, где по умолчанию Вручную)
    #    проблемой НЕ считается - скрипт ничего не ослабляет.
    $autoKinds = @('Automatic', 'AutomaticDelayed')
    if ($state.CurrentStartup -eq 'Disabled') {
        $state.ProblemKind = 'Startup'
    }
    elseif ($Definition.Kind -eq 'Driver') {
        # Драйверу достаточно любого значения, при котором он грузится сам.
        # Состояние Running отдельно не проверяем: после починки драйвер всё равно
        # поднимется только вместе с системой, и вечно красная строка путала бы игрока.
        if ($state.CurrentStartup -notin @('Boot', 'System', 'Automatic')) { $state.ProblemKind = 'Startup' }
    }
    elseif ($target -in $autoKinds) {
        if ($state.CurrentStartup -notin $autoKinds) { $state.ProblemKind = 'Startup' }
        elseif ($state.CurrentStatus -ne 'Running')  { $state.ProblemKind = 'Stopped' }
    }
    $state.IsProblem = ($state.ProblemKind -ne 'None')

    # 4. Что мы вправе чинить. Критические службы не трогаем ни при каких условиях.
    $state.CanFix = ($state.IsProblem -and (-not $Definition.Critical))

    # Если проблема есть, а чинить её мы не вправе - игрок не должен остаться
    # без объяснения, что делать. Молча показанная красная строка хуже, чем никакой.
    if ($state.IsProblem -and (-not $state.CanFix)) {
        $state.Hint = 'Критическая служба, утилита её не меняет. Включи вручную через services.msc'
    }

    return $state
}

# Состояние всех служб сразу: два запроса в WMI вместо тридцати.
function Get-AllServiceStates {
    $svcIndex = @{}
    try {
        foreach ($s in (Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)) {
            $svcIndex[$s.Name.ToLower()] = $s
        }
    }
    catch { }

    $drvIndex = @{}
    try {
        foreach ($d in (Get-CimInstance -ClassName Win32_SystemDriver -ErrorAction Stop)) {
            $drvIndex[$d.Name.ToLower()] = $d
        }
    }
    catch { }

    $result = @()
    foreach ($def in $SERVICES) {
        $result += Get-ServiceState -Definition $def -CimIndex $svcIndex -DriverIndex $drvIndex
    }

    # «Было» фиксируем ОДИН раз - при первом сканировании, чтобы отчёт показывал
    # картину до вмешательства. Это пруф для проверяющего на ScreenShare.
    foreach ($s in $result) {
        if (-not $App.Baseline.ContainsKey($s.Key)) {
            $App.Baseline[$s.Key] = [PSCustomObject]@{
                Exists    = $s.Exists
                Status    = $s.CurrentStatus
                Startup   = $s.CurrentStartup
                IsProblem = $s.IsProblem
            }
        }
    }

    return $result
}

# --- Исправление ---
# Чинит одну службу. Каждый шаг в своём try/catch: одна упавшая служба
# не должна ронять весь процесс.
function Repair-Service {
    param([Parameter(Mandatory = $true)]$State)

    $result = [PSCustomObject]@{
        Key         = $State.Key
        DisplayName = $State.DisplayName
        Success     = $true
        Errors      = @()
        Notes       = @()
    }

    if (-not $State.Exists) {
        $result.Success = $false
        $result.Errors += 'служба отсутствует в этой сборке Windows'
        return $result
    }

    # --- Предохранитель ---
    # Это единственное место во всём скрипте, откуда что-то пишется в систему.
    # Перед любой записью проверяем два условия:
    #   1) целевой тип запуска - одно из четырёх «включающих» значений.
    #      Отключить службу невозможно: значения «Disabled» нет ни в таблице
    #      $SERVICES, ни в функциях перевода (см. ConvertTo-ScStartValue);
    #   2) имя службы состоит только из латиницы, цифр и подчёркиваний -
    #      то есть пришло из захардкоженной таблицы, а не из чужих рук.
    #      Ни пробелов, ни кавычек, ни «&» в него попасть не может, поэтому
    #      подставить постороннюю команду в вызов sc.exe нельзя.
    # Не сошлось - не делаем ничего.
    if ($State.Target -notin @('Automatic', 'AutomaticDelayed', 'Manual', 'System')) {
        $result.Success = $false
        $result.Errors += "отказано: недопустимый целевой тип запуска «$($State.Target)»"
        return $result
    }
    if ($State.Name -notmatch '^[A-Za-z0-9_]{1,64}$') {
        $result.Success = $false
        $result.Errors += "отказано: недопустимое имя службы «$($State.Name)»"
        return $result
    }

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($State.Name)"

    # ШАГ 1. Вернуть заводской тип запуска.
    # Критические службы (DcomLaunch, PlugPlay) не трогаем вообще.
    if (-not $State.Critical) {
        try {
            if ($State.Kind -eq 'Driver' -or $State.Target -eq 'AutomaticDelayed') {
                # Драйверы и «автоматически (отложенный запуск)» Set-Service
                # в PowerShell 5.1 выставить не может - только sc.exe.
                $scValue = ConvertTo-ScStartValue $State.Target
                if ([string]::IsNullOrEmpty($scValue)) { throw "не удалось перевести тип запуска «$($State.Target)»" }
                & sc.exe config $State.Name start= $scValue | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "sc.exe config вернул код $LASTEXITCODE" }
            }
            else {
                Set-Service -Name $State.Name -StartupType $State.Target -ErrorAction Stop
            }
        }
        catch {
            $problem   = $_.Exception.Message
            $recovered = $false
            # Запасной путь для драйверов: то же самое значение прямой записью в реестр.
            if ($State.Kind -eq 'Driver') {
                try {
                    $value = ConvertFrom-StartupName $State.Target
                    if ($value -lt 0) { throw "неизвестный тип запуска «$($State.Target)»" }
                    Set-ItemProperty -LiteralPath $regPath -Name 'Start' -Value $value -Type DWord -ErrorAction Stop
                    $recovered = $true
                }
                catch { $problem = "$problem; запись в реестр: $($_.Exception.Message)" }
            }
            if (-not $recovered) {
                $result.Success = $false
                $result.Errors += "тип запуска: $problem"
            }
        }
    }

    # ШАГ 2. Запустить службу, если по заводским настройкам она должна работать.
    # Драйверы bam/dam стартуют только вместе с системой - им нужна перезагрузка.
    # Критические службы не запускаем тоже: это вторая защита на случай, если
    # такая служба всё же попадёт в очередь. Обратной операции (остановки)
    # в скрипте нет ни одной - искать бесполезно.
    if ((-not $State.Critical) -and $State.Kind -eq 'Service' -and $State.CurrentStatus -ne 'Running') {
        try {
            Start-Service -Name $State.Name -ErrorAction Stop
        }
        catch {
            # Службы с заводским типом «Вручную» (Appinfo, SSDPSRV, Wdi*) штатно
            # стоят остановленными и запускаются по запросу системы. Их отказ
            # стартовать по команде - не поломка: главное, что тип запуска
            # восстановлен. Поэтому это замечание, а не ошибка.
            if ($State.Target -eq 'Manual') {
                $result.Notes += "служба не запустилась вручную (для типа «Вручную» это нормально): $($_.Exception.Message)"
            }
            else {
                $result.Success = $false
                $result.Errors += "запуск: $($_.Exception.Message)"
            }
        }
    }

    return $result
}

# --- Отчёт ---
# «Отключён / Остановлена» одной строкой.
function Format-StateText {
    param([bool]$Exists, [string]$Startup, [string]$Status)
    if (-not $Exists) { return 'Не найдена' }
    return ('{0} / {1}' -f (Get-StartupRu $Startup), (Get-StatusRu $Status))
}

# Сохраняет текстовый отчёт на рабочий стол и возвращает путь к файлу.
function Export-Report {
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop)) { $desktop = [Environment]::GetFolderPath('MyDocuments') }

    $fileName = 'RuRBW_Report_{0}.txt' -f (Get-Date -Format 'yyyy-MM-dd_HH-mm')
    $path     = Join-Path -Path $desktop -ChildPath $fileName
    $rule     = '=' * 96
    $thin     = '-' * 96

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($rule)
    $lines.Add(' Russian Ranked Bedwars - Service Restorer ' + $SCRIPT_VERSION)
    $lines.Add(' Отчёт о состоянии системных служб Windows')
    $lines.Add($rule)
    $lines.Add((' Дата и время : {0}' -f (Get-Date -Format 'dd.MM.yyyy HH:mm:ss')))
    $lines.Add((' Компьютер    : {0}' -f $env:COMPUTERNAME))
    $lines.Add((' Пользователь : {0}\{1}' -f $env:USERDOMAIN, $env:USERNAME))
    $lines.Add((' Windows      : {0}' -f (Get-WindowsInfo)))
    $lines.Add($thin)
    $lines.Add(' В отчёте есть имя твоего компьютера и учётной записи Windows.')
    $lines.Add(' Показывай его только проверяющему на ScreenShare и не выкладывай')
    $lines.Add(' в общие чаты. Сама утилита никуда его не отправляет.')
    $lines.Add($thin)
    $lines.Add(' СОСТОЯНИЕ СЛУЖБ («было» зафиксировано при первом сканировании)')
    $lines.Add($thin)
    $lines.Add((' {0,-44}{1,-26}{2}' -f 'СЛУЖБА', 'БЫЛО', 'СТАЛО'))
    $lines.Add('')

    foreach ($s in $App.States) {
        $title = '{0} ({1})' -f $s.DisplayName, $s.Key
        if ($title.Length -gt 43) { $title = $title.Substring(0, 42) + '.' }

        $was = '—'
        if ($App.Baseline.ContainsKey($s.Key)) {
            $b   = $App.Baseline[$s.Key]
            $was = Format-StateText -Exists $b.Exists -Startup $b.Startup -Status $b.Status
        }
        $now = Format-StateText -Exists $s.Exists -Startup $s.CurrentStartup -Status $s.CurrentStatus

        $mark = '  '
        if ($s.IsProblem) { $mark = '! ' }
        $lines.Add(('{0}{1,-44}{2,-26}{3}' -f $mark, $title, $was, $now))
    }

    $wasProblems = 0
    foreach ($k in $App.Baseline.Keys) { if ($App.Baseline[$k].IsProblem) { $wasProblems++ } }
    $nowProblems = @($App.States | Where-Object { $_.IsProblem }).Count
    $missing     = @($App.States | Where-Object { -not $_.Exists }).Count

    $lines.Add('')
    $lines.Add($thin)
    $lines.Add(' ИТОГ')
    $lines.Add($thin)
    $lines.Add((' Проверено служб        : {0}' -f $App.States.Count))
    $lines.Add((' Нет в этой сборке      : {0}' -f $missing))
    $lines.Add((' Было с проблемами      : {0}' -f $wasProblems))
    $lines.Add((' Исправлено             : {0}' -f $App.Fixed))
    $lines.Add((' Не удалось исправить   : {0}' -f $App.Failed))
    $lines.Add((' Осталось с проблемами  : {0}' -f $nowProblems))
    $lines.Add((' Нужна перезагрузка     : {0}' -f $(if ($App.NeedReboot) { 'да' } else { 'нет' })))

    if ($App.Errors.Count -gt 0) {
        $lines.Add('')
        $lines.Add(' ОШИБКИ')
        foreach ($problem in $App.Errors) { $lines.Add('   ' + $problem) }
    }

    if ($App.Notes.Count -gt 0) {
        $lines.Add('')
        $lines.Add(' ЗАМЕЧАНИЯ (не ошибки)')
        foreach ($note in $App.Notes) { $lines.Add('   ' + $note) }
    }

    $lines.Add('')
    $lines.Add($thin)
    $lines.Add(' Утилита только включает службы Windows. Ничего не отключалось,')
    $lines.Add(' не удалялось и никуда не отправлялось.')
    $lines.Add(' Russian Ranked Bedwars — rurbw.pro | by @slurov')
    $lines.Add($rule)

    Set-Content -LiteralPath $path -Value $lines -Encoding UTF8 -ErrorAction Stop
    return $path
}

# --- Интерфейс: общие части ---
# Все шрифты создаём один раз и в конце освобождаем (см. Show-MainWindow).
function New-AppFonts {
    return @{
        Base        = New-Object System.Drawing.Font('Segoe UI', 9)
        Header      = New-Object System.Drawing.Font('Segoe UI', 11.5, [System.Drawing.FontStyle]::Bold)
        Summary     = New-Object System.Drawing.Font('Segoe UI', 13.5, [System.Drawing.FontStyle]::Bold)
        SummarySub  = New-Object System.Drawing.Font('Segoe UI', 9.5)
        SummaryHint = New-Object System.Drawing.Font('Segoe UI', 8.5)
        Section     = New-Object System.Drawing.Font('Segoe UI', 8.25)
        GridHead    = New-Object System.Drawing.Font('Segoe UI', 8.25)
        RowTitle    = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
        RowText     = New-Object System.Drawing.Font('Segoe UI', 9)
        Mono        = New-Object System.Drawing.Font('Consolas', 8.25)
        MonoBody    = New-Object System.Drawing.Font('Consolas', 9)
        Button      = New-Object System.Drawing.Font('Segoe UI', 9.5)
        ButtonMain  = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold)
        Status      = New-Object System.Drawing.Font('Segoe UI', 8.5)
        DialogTitle = New-Object System.Drawing.Font('Segoe UI', 11.5, [System.Drawing.FontStyle]::Bold)
        DialogText  = New-Object System.Drawing.Font('Segoe UI', 9.75)
        DialogNote  = New-Object System.Drawing.Font('Segoe UI', 9)
        ProgressTop = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
    }
}

# Текст на канве панели (используем TextRenderer: он рисует так же, как WinForms).
function Invoke-DrawText {
    param($Graphics, [string]$Text, $Font, [string]$ColorHex, $Rect, [string]$Flags = 'Left,Top,NoPrefix')
    if ([string]::IsNullOrEmpty($Text)) { return }
    [System.Windows.Forms.TextRenderer]::DrawText(
        $Graphics, $Text, $Font, $Rect, (Get-Color $ColorHex),
        ([System.Windows.Forms.TextFormatFlags]$Flags)
    )
}

# Высота текста при заданной ширине (для расчёта высоты окон).
function Measure-TextHeight {
    param([string]$Text, $Font, [int]$Width)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $size = [System.Windows.Forms.TextRenderer]::MeasureText(
        $Text, $Font, (New-Object System.Drawing.Size($Width, 0)),
        ([System.Windows.Forms.TextFormatFlags]'WordBreak,NoPrefix')
    )
    return $size.Height
}

# Цветной кружок-индикатор (в интерфейсе только цвет, без иконок и эмодзи).
function Invoke-DrawDot {
    param($Graphics, [string]$ColorHex, [int]$X, [int]$Y, [int]$Size = 6)
    $brush = New-Object System.Drawing.SolidBrush((Get-Color $ColorHex))
    $previousMode = $Graphics.SmoothingMode
    try {
        $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $Graphics.FillEllipse($brush, $X, $Y, $Size, $Size)
    }
    finally {
        $Graphics.SmoothingMode = $previousMode
        $brush.Dispose()
    }
}

# Плоская кнопка тёмной темы.
function New-FlatButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, [switch]$Primary, $Font)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.SetBounds($X, $Y, $Width, $Height)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.UseVisualStyleBackColor = $false
    $button.TabStop = $true
    if ($Font) { $button.Font = $Font }
    if ($Primary) { $button.Tag = 'primary' } else { $button.Tag = 'normal' }
    Set-ButtonState -Button $button -Enabled $true
    return $button
}

# Включает/выключает кнопку вместе с её цветами (штатная серая заливка
# WinForms в тёмной теме выглядит грязно).
function Set-ButtonState {
    param($Button, [bool]$Enabled)
    $Button.Enabled = $Enabled
    if ($Enabled) {
        if ($Button.Tag -eq 'primary') {
            $Button.BackColor = Get-Color $CLR.Accent
            $Button.ForeColor = Get-Color $CLR.AccentFg
            $Button.FlatAppearance.BorderColor        = Get-Color $CLR.AccentBd
            $Button.FlatAppearance.MouseOverBackColor = Get-Color '#BE2F43'
            $Button.FlatAppearance.MouseDownBackColor = Get-Color '#8E2131'
        }
        else {
            $Button.BackColor = Get-Color $CLR.Btn
            $Button.ForeColor = Get-Color $CLR.Text2
            $Button.FlatAppearance.BorderColor        = Get-Color $CLR.BtnBorder
            $Button.FlatAppearance.MouseOverBackColor = Get-Color $CLR.BtnHover
            $Button.FlatAppearance.MouseDownBackColor = Get-Color $CLR.BtnBorder
        }
        $Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    }
    else {
        $Button.BackColor = Get-Color $CLR.BtnOffBg
        $Button.ForeColor = Get-Color $CLR.BtnOffFg
        $Button.FlatAppearance.BorderColor        = Get-Color $CLR.BtnOffBd
        $Button.FlatAppearance.MouseOverBackColor = Get-Color $CLR.BtnOffBg
        $Button.FlatAppearance.MouseDownBackColor = Get-Color $CLR.BtnOffBg
        $Button.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# Модальное окно: заголовок, текст, приписка и одна-две кнопки.
# Возвращает 'primary' или 'secondary'.
function Show-DarkDialog {
    param(
        [string]$Title,
        [string]$Text,
        [string]$Note = '',
        [string]$PrimaryText = 'ОК',
        [string]$SecondaryText = '',
        $Owner = $null,
        [int]$Width = 460
    )

    $fonts  = $App.UI.Fonts
    $result = @{ Value = 'secondary' }
    $pad    = 22
    $inner  = $Width - ($pad * 2)

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text            = 'RuRBW Service Restorer'
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.ControlBox      = $false
    $dialog.ShowInTaskbar   = $false
    $dialog.MaximizeBox     = $false
    $dialog.MinimizeBox     = $false
    $dialog.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None
    $dialog.BackColor       = Get-Color $CLR.Panel
    $dialog.Font            = $fonts.Base
    if ($Owner) { $dialog.StartPosition = 'CenterParent' } else { $dialog.StartPosition = 'CenterScreen' }

    $y = 20

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = $Title
    $lblTitle.Font      = $fonts.DialogTitle
    $lblTitle.ForeColor = Get-Color $CLR.Text
    $lblTitle.AutoSize  = $false
    $lblTitle.SetBounds($pad, $y, $inner, (Measure-TextHeight -Text $Title -Font $fonts.DialogTitle -Width $inner))
    $dialog.Controls.Add($lblTitle)
    $y += $lblTitle.Height + 9

    $lblText = New-Object System.Windows.Forms.Label
    $lblText.Text      = $Text
    $lblText.Font      = $fonts.DialogText
    $lblText.ForeColor = Get-Color '#A8ADB4'
    $lblText.AutoSize  = $false
    $lblText.SetBounds($pad, $y, $inner, ((Measure-TextHeight -Text $Text -Font $fonts.DialogText -Width $inner) + 4))
    $dialog.Controls.Add($lblText)
    $y += $lblText.Height + 7

    if (-not [string]::IsNullOrWhiteSpace($Note)) {
        $lblNote = New-Object System.Windows.Forms.Label
        $lblNote.Text      = $Note
        $lblNote.Font      = $fonts.DialogNote
        $lblNote.ForeColor = Get-Color $CLR.Muted2
        $lblNote.AutoSize  = $false
        $lblNote.SetBounds($pad, $y, $inner, ((Measure-TextHeight -Text $Note -Font $fonts.DialogNote -Width $inner) + 3))
        $dialog.Controls.Add($lblNote)
        $y += $lblNote.Height + 4
    }

    $footerTop = $y + 16
    $dialog.ClientSize = New-Object System.Drawing.Size($Width, ($footerTop + 52))

    $footer = New-Object System.Windows.Forms.Panel
    $footer.SetBounds(0, $footerTop, $Width, 52)
    $footer.BackColor = Get-Color $CLR.Bg
    $footer.Add_Paint({
        param($src, $e)
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border2))
        try { $e.Graphics.DrawLine($pen, 0, 0, $src.Width, 0) } finally { $pen.Dispose() }
    })
    $dialog.Controls.Add($footer)

    $right = $Width - $pad

    $btnPrimary = New-FlatButton -Text $PrimaryText -X 0 -Y 10 -Width 10 -Height 32 -Primary -Font $fonts.Button
    $primaryWidth = [Math]::Max(96, ([System.Windows.Forms.TextRenderer]::MeasureText($PrimaryText, $fonts.Button).Width + 34))
    $btnPrimary.SetBounds(($right - $primaryWidth), 10, $primaryWidth, 32)
    $btnPrimary.Add_Click({ $result.Value = 'primary'; $dialog.Close() }.GetNewClosure())
    $footer.Controls.Add($btnPrimary)
    $dialog.AcceptButton = $btnPrimary

    if (-not [string]::IsNullOrWhiteSpace($SecondaryText)) {
        $secondaryWidth = [Math]::Max(84, ([System.Windows.Forms.TextRenderer]::MeasureText($SecondaryText, $fonts.Button).Width + 30))
        $btnSecondary = New-FlatButton -Text $SecondaryText `
            -X ($right - $primaryWidth - 8 - $secondaryWidth) -Y 10 -Width $secondaryWidth -Height 32 -Font $fonts.Button
        $btnSecondary.Add_Click({ $result.Value = 'secondary'; $dialog.Close() }.GetNewClosure())
        $footer.Controls.Add($btnSecondary)
        $dialog.CancelButton = $btnSecondary
    }

    try {
        if ($Owner) { $dialog.ShowDialog($Owner) | Out-Null } else { $dialog.ShowDialog() | Out-Null }
    }
    finally { $dialog.Dispose() }

    return $result.Value
}

# Окно «Нужны права администратора»: показываем, когда игрок
# нажал «Нет» в окне контроля учётных записей.
function Show-NoAdminWindow {
    $fonts = $App.UI.Fonts
    $width = 520
    $pad   = 40
    $inner = $width - ($pad * 2)

    $titleText = 'Нужны права администратора'
    $bodyText  = 'Изменять службы Windows может только администратор. Нажми кнопку ниже и подтверди запрос Windows — программа перезапустится и продолжит проверку.'
    $hintText  = 'Если окно с запросом не появилось, закрой программу и запусти команду заново.'

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'RuRBW Service Restorer | rurbw.pro'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox     = $false
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None
    $form.BackColor       = Get-Color $CLR.Bg
    $form.Font            = $fonts.Base
    $form.ClientSize      = New-Object System.Drawing.Size($width, 300)

    # Вместо иконки - фирменная красная полоса (иконки и эмодзи не используем).
    $accentBar = New-Object System.Windows.Forms.Panel
    $accentBar.SetBounds($pad, 44, 46, 3)
    $accentBar.BackColor = Get-Color $CLR.Accent
    $form.Controls.Add($accentBar)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = $titleText
    $lblTitle.Font      = $fonts.Summary
    $lblTitle.ForeColor = Get-Color $CLR.Text
    $lblTitle.AutoSize  = $false
    $lblTitle.SetBounds($pad, 62, $inner, 30)
    $form.Controls.Add($lblTitle)

    $lblBody = New-Object System.Windows.Forms.Label
    $lblBody.Text      = $bodyText
    $lblBody.Font      = $fonts.DialogText
    $lblBody.ForeColor = Get-Color '#A8ADB4'
    $lblBody.AutoSize  = $false
    $lblBody.SetBounds($pad, 98, $inner, 62)
    $form.Controls.Add($lblBody)

    $lblHint = New-Object System.Windows.Forms.Label
    $lblHint.Text      = $hintText
    $lblHint.Font      = $fonts.DialogNote
    $lblHint.ForeColor = Get-Color $CLR.Muted2
    $lblHint.AutoSize  = $false
    $lblHint.SetBounds($pad, 218, $inner, 36)
    $form.Controls.Add($lblHint)

    $btnElevate = New-FlatButton -Text 'Перезапустить от имени администратора' `
        -X $pad -Y 168 -Width 300 -Height 36 -Primary -Font $fonts.ButtonMain
    $form.Controls.Add($btnElevate)

    $btnClose = New-FlatButton -Text 'Закрыть' -X ($pad + 310) -Y 168 -Width 96 -Height 36 -Font $fonts.Button
    $btnClose.Add_Click({ $form.Close() }.GetNewClosure())
    $form.Controls.Add($btnClose)

    $btnElevate.Add_Click({
        if (Invoke-Elevate) {
            $form.Close()
        }
        else {
            $lblHint.ForeColor = Get-Color $CLR.RedText
            $lblHint.Text      = 'Windows не выдала права. Нажми «Да» в окне контроля учётных записей — без этого включить службы невозможно.'
        }
    }.GetNewClosure())

    $lblCode = New-Object System.Windows.Forms.Label
    $lblCode.Text      = 'Код: ERROR_ACCESS_DENIED (5)'
    $lblCode.Font      = $fonts.Mono
    $lblCode.ForeColor = Get-Color $CLR.Muted2
    $lblCode.AutoSize  = $false
    $lblCode.SetBounds($pad, 262, $inner, 18)
    $form.Controls.Add($lblCode)

    try { $form.ShowDialog() | Out-Null } finally { $form.Dispose() }
}

# Окно обратного отсчёта после команды на перезагрузку.
# Кнопка «Отменить» выполняет `shutdown /a`.
function Show-CountdownWindow {
    param($Owner, [int]$Seconds = 10)

    $fonts = $App.UI.Fonts
    $width = 420
    $state = @{ Left = $Seconds; Cancelled = $false }

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'RuRBW Service Restorer'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.ControlBox      = $false
    $form.ShowInTaskbar   = $false
    $form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
    $form.BackColor       = Get-Color $CLR.Panel
    $form.Font            = $fonts.Base
    $form.ClientSize      = New-Object System.Drawing.Size($width, 168)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text      = 'Компьютер перезагрузится'
    $lblTitle.Font      = $fonts.DialogTitle
    $lblTitle.ForeColor = Get-Color $CLR.Text
    $lblTitle.AutoSize  = $false
    $lblTitle.SetBounds(22, 20, ($width - 44), 24)
    $form.Controls.Add($lblTitle)

    $lblText = New-Object System.Windows.Forms.Label
    $lblText.Text      = "Перезагрузка через $Seconds сек. Сохрани всё важное."
    $lblText.Font      = $fonts.DialogText
    $lblText.ForeColor = Get-Color '#A8ADB4'
    $lblText.AutoSize  = $false
    $lblText.SetBounds(22, 52, ($width - 44), 40)
    $form.Controls.Add($lblText)

    $footer = New-Object System.Windows.Forms.Panel
    $footer.SetBounds(0, 116, $width, 52)
    $footer.BackColor = Get-Color $CLR.Bg
    $footer.Add_Paint({
        param($src, $e)
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border2))
        try { $e.Graphics.DrawLine($pen, 0, 0, $src.Width, 0) } finally { $pen.Dispose() }
    })
    $form.Controls.Add($footer)

    $btnCancel = New-FlatButton -Text 'Отменить' -X ($width - 22 - 110) -Y 10 -Width 110 -Height 32 -Font $fonts.Button
    $footer.Controls.Add($btnCancel)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000

    $btnCancel.Add_Click({
        try { & shutdown.exe /a | Out-Null } catch { }
        $state.Cancelled = $true
        $timer.Stop()
        $form.Close()
    }.GetNewClosure())

    $timer.Add_Tick({
        $state.Left = $state.Left - 1
        if ($state.Left -le 0) {
            $timer.Stop()
            $lblText.Text = 'Перезагрузка...'
            $form.Close()
        }
        else {
            $lblText.Text = "Перезагрузка через $($state.Left) сек. Сохрани всё важное."
        }
    }.GetNewClosure())

    $form.Add_Shown({ $timer.Start() }.GetNewClosure())
    $form.Add_FormClosed({ $timer.Stop(); $timer.Dispose() }.GetNewClosure())

    try {
        if ($Owner) { $form.ShowDialog($Owner) | Out-Null } else { $form.ShowDialog() | Out-Null }
    }
    finally { $form.Dispose() }

    return $state.Cancelled
}

# --- Интерфейс: логика главного окна ---
function Set-StatusText {
    param([string]$Text)
    if ($App.UI.StatusLeft) { $App.UI.StatusLeft.Text = $Text }
    if ($App.UI.Status) { $App.UI.Status.Refresh() }
}

# Пересобирает карточку-сводку над таблицей и текст в строке состояния.
function Update-Summary {
    $total    = @($App.States).Count
    $problems = @($App.States | Where-Object { $_.IsProblem })
    $disabled = @($App.States | Where-Object { $_.ProblemKind -eq 'Startup' })
    $stopped  = @($App.States | Where-Object { $_.ProblemKind -eq 'Stopped' })
    $missing  = @($App.States | Where-Object { -not $_.Exists })

    if ($problems.Count -eq 0) {
        $data = @{
            Color     = $CLR.Green
            Title     = "Все службы работают: $($total - $missing.Count) из $total"
            Text      = 'Журналы запуска программ ведутся. К проверке компьютера претензий не будет.'
            Breakdown = ''
        }
        Set-StatusText "Проверено служб: $total, все в порядке"
    }
    else {
        $color = $CLR.Amber
        if ($disabled.Count -gt 0) { $color = $CLR.Red }
        $data = @{
            Color = $color
            Title = "Не работает служб: $($problems.Count) из $total"
            Text  = 'Пока эти службы выключены, на проверке за них можно получить бан, и с каждым разом длительность бана растёт. Кнопка внизу включает их обратно.'
            Breakdown = "С неправильным типом запуска: $($disabled.Count) — сами после перезагрузки не поднимутся. Просто остановлено: $($stopped.Count)."
        }
        Set-StatusText "Проверено служб: $total, с проблемами: $($problems.Count)"
    }

    if ($missing.Count -gt 0) {
        $tail = "Нет в этой сборке Windows: $($missing.Count) — это не ошибка."
        if ($data.Breakdown) { $data.Breakdown = $data.Breakdown + ' ' + $tail } else { $data.Breakdown = $tail }
    }

    $App.UI.SummaryData = $data
    $App.UI.Summary.Invalidate()
}

# Пересчитывает галочки: состояние кнопки «Включить», подсказку и «Выбрать все».
function Update-Selection {
    $grid    = $App.UI.Grid
    $fixable = 0
    $checked = 0
    foreach ($row in $grid.Rows) {
        $st = $row.Tag
        if ($st -and $st.CanFix) {
            $fixable++
            if ([bool]$row.Cells[0].Value) { $checked++ }
        }
    }

    Set-ButtonState -Button $App.UI.BtnFix -Enabled (($checked -gt 0) -and (-not $App.Running))

    if ($fixable -eq 0) { $App.UI.SectionHint.Text = "Служб в списке: $(@($App.States).Count)" }
    else { $App.UI.SectionHint.Text = "Выбрано $checked из $fixable" }

    $App.Suppress = $true
    $App.UI.ChkAll.Checked = (($fixable -gt 0) -and ($checked -eq $fixable))
    $App.UI.ChkAll.Enabled = (($fixable -gt 0) -and (-not $App.Running))
    $App.Suppress = $false
}

# Перерисовывает таблицу по $App.States.
function Update-View {
    $grid = $App.UI.Grid
    $App.Populating = $true
    try {
        $grid.Rows.Clear()

        # Сначала службы с неправильным типом запуска, затем просто остановленные,
        # затем рабочие, в самом конце - отсутствующие в этой сборке Windows.
        $sorted = $App.States | Sort-Object -Property `
            @{ Expression = {
                    $item = $_
                    if ($item.ProblemKind -eq 'Startup') { 0 }
                    elseif ($item.ProblemKind -eq 'Stopped') { 1 }
                    elseif ($item.Exists) { 2 }
                    else { 3 }
                } },
            @{ Expression = { $_.DisplayName } }

        foreach ($st in $sorted) {
            $statusText  = 'Не найдена'
            $startupText = '—'
            if ($st.Exists) {
                $statusText  = Get-StatusRu $st.CurrentStatus
                $startupText = Get-StartupRu $st.CurrentStartup
            }
            $index = $grid.Rows.Add(@([bool]$st.CanFix, $st.DisplayName, $statusText, $startupText, $st.Description))
            $row = $grid.Rows[$index]
            $row.Tag = $st
            $row.Height = 43
            # Критические и отсутствующие службы трогать нельзя - галочка недоступна.
            $row.Cells[0].ReadOnly = (-not $st.CanFix)
        }
    }
    finally { $App.Populating = $false }

    $grid.ClearSelection()
    # Снимаем «текущую ячейку», чтобы первая строка не выглядела выбранной.
    # В отдельных состояниях DataGridView на это ругается - падать из-за косметики нельзя.
    try { $grid.CurrentCell = $null } catch { }
    Update-Summary
    Update-Selection
}

# Сканирование системы.
function Invoke-Scan {
    Set-StatusText 'Проверяю службы Windows...'
    [System.Windows.Forms.Application]::DoEvents()
    $App.States = Get-AllServiceStates
    Update-View
}

# Перезагрузка с обратным отсчётом.
function Invoke-Reboot {
    param($Owner)

    # shutdown.exe возвращает код ошибки Windows. Разбираем два случая отдельно,
    # чтобы игрок понял, что произошло.
    $code    = 0
    $failure = ''
    try {
        & shutdown.exe /r /t 10 /c 'RuRBW Service Restorer' | Out-Null
        $code = $LASTEXITCODE
    }
    catch {
        $code    = -1
        $failure = $_.Exception.Message
    }

    if ($code -ne 0) {
        $explanation = "Windows не приняла команду перезагрузки (код $code)."
        if ($code -eq 1190) {
            # 1190 = перезагрузка уже запланирована другой программой.
            # Чужую команду мы не отменяем: shutdown /a тут вызывать нельзя,
            # иначе утилита сорвёт чей-то чужой запланированный перезапуск.
            $explanation = 'Перезагрузка уже запланирована другой программой. Утилита не отменяет чужие команды — дождись её или отмени сам.'
        }
        elseif ($code -eq -1) {
            $explanation = "Не удалось выполнить команду перезагрузки: $failure"
        }
        Show-DarkDialog -Owner $Owner -Title 'Не получилось перезагрузить' `
            -Text $explanation `
            -Note 'Перезагрузи компьютер вручную — без этого часть изменений не применится.' `
            -PrimaryText 'Понятно' | Out-Null
        return
    }

    $cancelled = Show-CountdownWindow -Owner $Owner -Seconds 10
    if ($cancelled) { Set-StatusText 'Перезагрузка отменена. Изменения применятся после следующей перезагрузки' }
    else { Set-StatusText 'Перезагрузка компьютера...' }
}

# Включение выбранных служб: прогресс, сводка, предложение перезагрузиться.
function Invoke-FixSelected {
    $grid  = $App.UI.Grid
    $queue = @()
    foreach ($row in $grid.Rows) {
        $st = $row.Tag
        if ($st -and $st.CanFix -and [bool]$row.Cells[0].Value) { $queue += $st }
    }
    if ($queue.Count -eq 0) { return }

    $App.Running  = $true
    $App.Fixed    = 0
    $App.Failed   = 0
    $App.Errors   = @()
    $App.Notes    = @()
    $App.Progress.Total = $queue.Count
    $App.Progress.Index = 0
    $App.Progress.Line  = ''
    $hadError = @{}

    $App.UI.Summary.Visible  = $false
    $App.UI.Progress.Visible = $true
    $grid.Enabled = $false
    Set-ButtonState -Button $App.UI.BtnFix     -Enabled $false
    Set-ButtonState -Button $App.UI.BtnRefresh -Enabled $false
    Set-ButtonState -Button $App.UI.BtnReport  -Enabled $false
    $App.UI.ChkAll.Enabled = $false
    $App.UI.BtnFix.Text = 'Включение...'
    Set-StatusText 'Включение служб...'

    try {
        $done = 0
        foreach ($st in $queue) {
            $action = 'запуск службы'
            if ($st.ProblemKind -eq 'Startup') {
                $action = "тип запуска «$(Get-StartupRu $st.Target)»"
                if ($st.Kind -eq 'Service') { $action += ', запуск службы' }
            }
            $App.Progress.Index = $done
            $App.Progress.Line  = "$($st.Name) — $action"
            $App.UI.Progress.Invalidate()
            $App.UI.Progress.Update()
            # Без DoEvents окно «зависает» на время исправления.
            [System.Windows.Forms.Application]::DoEvents()

            $result = Repair-Service -State $st

            foreach ($note in $result.Notes) {
                $App.Notes += "$($st.DisplayName) [$($st.Key)] — $note"
            }

            if (-not $result.Success) {
                $hadError[$st.Key] = $true
                foreach ($problem in $result.Errors) {
                    $App.Errors += "$($st.DisplayName) [$($st.Key)] — $problem"
                }
            }
            else {
                # Тип запуска и драйверы применяются только после перезагрузки.
                if ($st.ProblemKind -eq 'Startup' -or $st.Kind -eq 'Driver') { $App.NeedReboot = $true }
            }

            $done++
            $App.Progress.Index = $done
            $App.UI.Progress.Invalidate()
            $App.UI.Progress.Update()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    finally {
        $App.Running = $false
        $App.UI.BtnFix.Text = 'Включить выбранные службы'
        $App.UI.Progress.Visible = $false
        $App.UI.Summary.Visible  = $true
        $grid.Enabled = $true
        Set-ButtonState -Button $App.UI.BtnRefresh -Enabled $true
        Set-ButtonState -Button $App.UI.BtnReport  -Enabled $true
    }

    Invoke-Scan

    # Результат считаем ПО ФАКТУ, а не по кодам возврата: сверяем очередь с тем,
    # что показало повторное сканирование. Если команда прошла без ошибки, а
    # состояние не изменилось (например, твикер в автозагрузке вернул его назад),
    # честнее показать «не исправлено», чем отчитаться об успехе.
    $App.Fixed  = 0
    $App.Failed = 0
    foreach ($st in $queue) {
        $after = $App.States | Where-Object { $_.Key -eq $st.Key } | Select-Object -First 1
        if ($after -and (-not $after.IsProblem)) {
            $App.Fixed++
        }
        else {
            $App.Failed++
            if (-not $hadError.ContainsKey($st.Key)) {
                $App.Errors += "$($st.DisplayName) [$($st.Key)] — команда выполнена без ошибки, но состояние не изменилось. Проверь, не возвращает ли настройку твикер из автозагрузки"
            }
        }
    }

    $errorText = ''
    if ($App.Errors.Count -gt 0) {
        $shown = @($App.Errors | Select-Object -First 4)
        $errorText = $shown -join "`r`n"
        if ($App.Errors.Count -gt 4) {
            $errorText += "`r`n… и ещё $($App.Errors.Count - 4). Полный список — в отчёте."
        }
    }

    if ($App.Fixed -gt 0) {
        Set-StatusText "Включено служб: $($App.Fixed). Ошибок: $($App.Failed). Нужна перезагрузка"
        $note = 'До перезагрузки часть служб на проверке всё ещё считается отключённой.'
        if ($errorText) { $note = "Не удалось исправить: $($App.Failed)." + "`r`n" + $errorText }

        $answer = Show-DarkDialog -Owner $App.UI.Form `
            -Title 'Службы восстановлены' `
            -Text "Исправлено служб: $($App.Fixed). Чтобы изменения применились, нужна перезагрузка компьютера. Перезагрузить сейчас?" `
            -Note $note `
            -PrimaryText 'Перезагрузить' -SecondaryText 'Позже' -Width 470

        if ($answer -eq 'primary') { Invoke-Reboot -Owner $App.UI.Form }
        else { Set-StatusText 'Перезагрузка отложена. Изменения применятся после неё' }
    }
    else {
        Set-StatusText "Не удалось включить службы. Ошибок: $($App.Failed)"
        Show-DarkDialog -Owner $App.UI.Form `
            -Title 'Не удалось включить службы' `
            -Text 'Windows отказала в изменении. Обычно это значит, что права администратора отозваны политикой или служба заблокирована сторонней программой.' `
            -Note $errorText -PrimaryText 'Понятно' -Width 470 | Out-Null
    }
}

# Сохранение отчёта на рабочий стол.
function Invoke-SaveReport {
    try {
        $path = Export-Report
        Set-StatusText "Отчёт сохранён: $path"
        Show-DarkDialog -Owner $App.UI.Form -Title 'Отчёт сохранён' `
            -Text 'Файл лежит на рабочем столе. Его можно показать проверяющему.' `
            -Note $path -PrimaryText 'Понятно' -Width 480 | Out-Null
    }
    catch {
        Show-DarkDialog -Owner $App.UI.Form -Title 'Не удалось сохранить отчёт' `
            -Text $_.Exception.Message -PrimaryText 'Понятно' | Out-Null
    }
}

# --- Интерфейс: главное окно ---
function Show-MainWindow {
    $fonts = New-AppFonts
    $App.UI.Fonts = $fonts

    # --- окно ---
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'RuRBW Service Restorer | rurbw.pro'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox     = $false
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None
    $form.ClientSize      = New-Object System.Drawing.Size(760, 620)
    $form.BackColor       = Get-Color $CLR.Bg
    $form.ForeColor       = Get-Color $CLR.Text2
    $form.Font            = $fonts.Base
    $App.UI.Form          = $form

    # --- шапка ---
    $header = New-Object System.Windows.Forms.Panel
    $header.SetBounds(0, 0, 760, 62)
    $header.BackColor = Get-Color $CLR.Bg
    $header.Add_Paint({
        param($src, $e)
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border2))
        try { $e.Graphics.DrawLine($pen, 0, ($src.Height - 1), $src.Width, ($src.Height - 1)) }
        finally { $pen.Dispose() }
    })
    $form.Controls.Add($header)

    $lblApp = New-Object System.Windows.Forms.Label
    $lblApp.Text      = 'Russian Ranked Bedwars Service Restorer'
    $lblApp.Font      = $fonts.Header
    $lblApp.ForeColor = Get-Color $CLR.Text
    $lblApp.AutoSize  = $false
    $lblApp.SetBounds(16, 10, 430, 22)
    $header.Controls.Add($lblApp)

    $lnkDiscord = New-Object System.Windows.Forms.LinkLabel
    $lnkDiscord.Text            = 'discord.gg/rurbw'
    $lnkDiscord.Font            = $fonts.RowText
    $lnkDiscord.LinkColor       = Get-Color $CLR.Muted
    $lnkDiscord.ActiveLinkColor = Get-Color $CLR.Text2
    $lnkDiscord.VisitedLinkColor= Get-Color $CLR.Muted
    $lnkDiscord.LinkBehavior    = [System.Windows.Forms.LinkBehavior]::HoverUnderline
    $lnkDiscord.AutoSize        = $true
    $lnkDiscord.Location        = New-Object System.Drawing.Point(16, 36)
    # Единственное, что открывает ссылку, - явное нажатие игрока.
    # Открываем через explorer.exe, чтобы браузер НЕ унаследовал права
    # администратора этого процесса (запускать браузер от админа - плохая идея).
    $lnkDiscord.Add_LinkClicked({
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList $DISCORD_URL }
        catch { }
    })
    $header.Controls.Add($lnkDiscord)

    $badge = New-Object System.Windows.Forms.Panel
    $badge.SetBounds(612, 12, 132, 22)
    $badge.BackColor = Get-Color $CLR.BadgeBg
    $badge.Add_Paint({
        param($src, $e)
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.BadgeBd))
        try { $e.Graphics.DrawRectangle($pen, 0, 0, ($src.Width - 1), ($src.Height - 1)) }
        finally { $pen.Dispose() }
        Invoke-DrawDot -Graphics $e.Graphics -ColorHex $CLR.Green -X 10 -Y 8 -Size 6
        Invoke-DrawText -Graphics $e.Graphics -Text 'Администратор' -Font $App.UI.Fonts.SummaryHint `
            -ColorHex $CLR.GreenText -Rect (New-Object System.Drawing.Rectangle(21, 0, 105, ($src.Height))) `
            -Flags 'Left,VerticalCenter,NoPrefix'
    })
    $header.Controls.Add($badge)

    $lblAuthor = New-Object System.Windows.Forms.Label
    $lblAuthor.Text      = 'by @slurov'
    $lblAuthor.Font      = $fonts.Section
    $lblAuthor.ForeColor = Get-Color $CLR.Muted2
    $lblAuthor.AutoSize  = $false
    $lblAuthor.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $lblAuthor.SetBounds(584, 38, 160, 16)
    $header.Controls.Add($lblAuthor)

    # --- карточка «сводка» ---
    $summary = New-Object System.Windows.Forms.Panel
    $summary.SetBounds(16, 74, 728, 104)
    $summary.BackColor = Get-Color $CLR.Panel
    $summary.Add_Paint({
        param($src, $e)
        $data = $App.UI.SummaryData
        if (-not $data) { return }
        $g = $e.Graphics
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border))
        try { $g.DrawRectangle($pen, 0, 0, ($src.Width - 1), ($src.Height - 1)) } finally { $pen.Dispose() }

        Invoke-DrawDot -Graphics $g -ColorHex $data.Color -X 16 -Y 19 -Size 9

        $textWidth = $src.Width - 52
        Invoke-DrawText -Graphics $g -Text $data.Title -Font $App.UI.Fonts.Summary -ColorHex $CLR.Text `
            -Rect (New-Object System.Drawing.Rectangle(33, 10, $textWidth, 27)) -Flags 'Left,Top,NoPrefix,EndEllipsis'
        Invoke-DrawText -Graphics $g -Text $data.Text -Font $App.UI.Fonts.SummarySub -ColorHex '#A8ADB4' `
            -Rect (New-Object System.Drawing.Rectangle(33, 40, $textWidth, 40)) -Flags 'Left,Top,NoPrefix,WordBreak'
        if ($data.Breakdown) {
            Invoke-DrawText -Graphics $g -Text $data.Breakdown -Font $App.UI.Fonts.SummaryHint -ColorHex $CLR.Muted3 `
                -Rect (New-Object System.Drawing.Rectangle(33, 80, $textWidth, 17)) -Flags 'Left,Top,NoPrefix,EndEllipsis'
        }
    })
    $form.Controls.Add($summary)
    $App.UI.Summary = $summary

    # --- карточка «идёт исправление» ---
    $progress = New-Object System.Windows.Forms.Panel
    $progress.SetBounds(16, 74, 728, 104)
    $progress.BackColor = Get-Color $CLR.Panel
    $progress.Visible   = $false
    $progress.Add_Paint({
        param($src, $e)
        $g = $e.Graphics
        $p = $App.Progress
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border))
        try { $g.DrawRectangle($pen, 0, 0, ($src.Width - 1), ($src.Height - 1)) } finally { $pen.Dispose() }

        Invoke-DrawDot -Graphics $g -ColorHex $CLR.Accent -X 16 -Y 18 -Size 9
        Invoke-DrawText -Graphics $g -Text 'Включение служб' -Font $App.UI.Fonts.ProgressTop -ColorHex $CLR.Text `
            -Rect (New-Object System.Drawing.Rectangle(33, 12, 320, 22)) -Flags 'Left,Top,NoPrefix'
        Invoke-DrawText -Graphics $g -Text "$($p.Index) / $($p.Total)" -Font $App.UI.Fonts.RowText -ColorHex $CLR.Muted `
            -Rect (New-Object System.Drawing.Rectangle(($src.Width - 180), 14, 164, 18)) -Flags 'Right,Top,NoPrefix'

        $barWidth = $src.Width - 32
        $back = New-Object System.Drawing.SolidBrush((Get-Color $CLR.Chrome))
        try { $g.FillRectangle($back, 16, 50, $barWidth, 4) } finally { $back.Dispose() }
        if ($p.Total -gt 0 -and $p.Index -gt 0) {
            $done = [int]($barWidth * ($p.Index / $p.Total))
            $fill = New-Object System.Drawing.SolidBrush((Get-Color $CLR.Accent))
            try { $g.FillRectangle($fill, 16, 50, $done, 4) } finally { $fill.Dispose() }
        }
        Invoke-DrawText -Graphics $g -Text $p.Line -Font $App.UI.Fonts.MonoBody -ColorHex '#A8ADB4' `
            -Rect (New-Object System.Drawing.Rectangle(16, 66, $barWidth, 18)) -Flags 'Left,Top,NoPrefix,EndEllipsis'
    })
    $form.Controls.Add($progress)
    $App.UI.Progress = $progress

    # --- заголовок раздела ---
    $lblSection = New-Object System.Windows.Forms.Label
    $lblSection.Text      = 'СЛУЖБЫ WINDOWS'
    $lblSection.Font      = $fonts.Section
    $lblSection.ForeColor = Get-Color $CLR.Muted2
    $lblSection.AutoSize  = $false
    $lblSection.SetBounds(18, 186, 300, 16)
    $form.Controls.Add($lblSection)

    $lblHint = New-Object System.Windows.Forms.Label
    $lblHint.Text      = ''
    $lblHint.Font      = $fonts.SummaryHint
    $lblHint.ForeColor = Get-Color $CLR.Muted2
    $lblHint.AutoSize  = $false
    $lblHint.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $lblHint.SetBounds(444, 185, 300, 17)
    $form.Controls.Add($lblHint)
    $App.UI.SectionHint = $lblHint

    # --- таблица ---
    $gridHost = New-Object System.Windows.Forms.Panel
    $gridHost.SetBounds(16, 208, 728, 344)
    $gridHost.BackColor = Get-Color $CLR.Panel
    $gridHost.Add_Paint({
        param($src, $e)
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border))
        try { $e.Graphics.DrawRectangle($pen, 0, 0, ($src.Width - 1), ($src.Height - 1)) }
        finally { $pen.Dispose() }
    })
    $form.Controls.Add($gridHost)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.SetBounds(1, 1, 726, 342)
    $grid.BackgroundColor            = Get-Color $CLR.Panel
    $grid.GridColor                  = Get-Color $CLR.Line
    $grid.BorderStyle                = [System.Windows.Forms.BorderStyle]::None
    $grid.CellBorderStyle            = [System.Windows.Forms.DataGridViewCellBorderStyle]::None
    $grid.ColumnHeadersBorderStyle   = [System.Windows.Forms.DataGridViewHeaderBorderStyle]::None
    $grid.EnableHeadersVisualStyles  = $false
    $grid.ColumnHeadersHeightSizeMode= [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.ColumnHeadersHeight        = 29
    $grid.RowTemplate.Height         = 43
    $grid.AllowUserToAddRows         = $false
    $grid.AllowUserToDeleteRows      = $false
    $grid.AllowUserToResizeRows      = $false
    $grid.AllowUserToResizeColumns   = $false
    $grid.AllowUserToOrderColumns    = $false
    $grid.RowHeadersVisible          = $false
    $grid.SelectionMode              = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.MultiSelect                = $false
    $grid.ScrollBars                 = [System.Windows.Forms.ScrollBars]::Vertical
    $grid.ShowCellToolTips           = $false
    $grid.TabStop                    = $true

    # Тёмная тема в DataGridView не наследуется - задаём цвета явно.
    $grid.DefaultCellStyle.BackColor          = Get-Color $CLR.Panel
    $grid.DefaultCellStyle.ForeColor          = Get-Color $CLR.Text2
    $grid.DefaultCellStyle.SelectionBackColor = Get-Color $CLR.RowSel
    $grid.DefaultCellStyle.SelectionForeColor = Get-Color $CLR.Text
    $grid.DefaultCellStyle.Font               = $fonts.RowText
    $grid.RowsDefaultCellStyle.BackColor      = Get-Color $CLR.Panel
    $grid.ColumnHeadersDefaultCellStyle.BackColor          = Get-Color $CLR.PanelHead
    $grid.ColumnHeadersDefaultCellStyle.ForeColor          = Get-Color $CLR.Head
    $grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = Get-Color $CLR.PanelHead
    $grid.ColumnHeadersDefaultCellStyle.SelectionForeColor = Get-Color $CLR.Head
    $grid.ColumnHeadersDefaultCellStyle.Font               = $fonts.GridHead

    # Двойная буферизация: без неё таблица мерцает при перерисовке.
    try {
        $property = [System.Windows.Forms.Control].GetProperty('DoubleBuffered',
            ([System.Reflection.BindingFlags]'Instance,NonPublic'))
        $property.SetValue($grid, $true, $null)
    }
    catch { }

    $colSelect = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $colSelect.Name = 'Select'
    $colSelect.HeaderText = ''
    $colSelect.Width = 34
    $colSelect.Resizable = [System.Windows.Forms.DataGridViewTriState]::False
    $colSelect.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

    $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colName.Name = 'Service'
    $colName.HeaderText = 'Служба'
    $colName.Width = 202
    $colName.ReadOnly = $true
    $colName.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

    $colState = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colState.Name = 'State'
    $colState.HeaderText = 'Состояние'
    $colState.Width = 96
    $colState.ReadOnly = $true
    $colState.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

    $colStartup = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colStartup.Name = 'Startup'
    $colStartup.HeaderText = 'Тип запуска'
    $colStartup.Width = 112
    $colStartup.ReadOnly = $true
    $colStartup.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable

    $colDescription = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colDescription.Name = 'Description'
    $colDescription.HeaderText = 'Что делает'
    $colDescription.ReadOnly = $true
    $colDescription.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    $colDescription.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill

    $grid.Columns.AddRange([System.Windows.Forms.DataGridViewColumn[]]@(
        $colSelect, $colName, $colState, $colStartup, $colDescription))
    $gridHost.Controls.Add($grid)
    $App.UI.Grid = $grid

    # Рисуем строки сами: подсветка, двухстрочное имя службы и цветные индикаторы.
    $grid.Add_CellPainting({
        param($src, $e)
        if ($e.ColumnIndex -lt 0) { return }
        $g = $e.Graphics

        # --- шапка таблицы ---
        if ($e.RowIndex -lt 0) {
            $brush = New-Object System.Drawing.SolidBrush((Get-Color $CLR.PanelHead))
            try { $g.FillRectangle($brush, $e.CellBounds) } finally { $brush.Dispose() }
            $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border))
            try {
                $g.DrawLine($pen, $e.CellBounds.Left, ($e.CellBounds.Bottom - 1), $e.CellBounds.Right, ($e.CellBounds.Bottom - 1))
            }
            finally { $pen.Dispose() }
            $headerText = [string]$e.FormattedValue
            if ($headerText) {
                Invoke-DrawText -Graphics $g -Text $headerText.ToUpper() -Font $App.UI.Fonts.GridHead -ColorHex $CLR.Head `
                    -Rect (New-Object System.Drawing.Rectangle(($e.CellBounds.X + 5), $e.CellBounds.Y, ($e.CellBounds.Width - 7), $e.CellBounds.Height)) `
                    -Flags 'Left,VerticalCenter,NoPrefix,EndEllipsis'
            }
            $e.Handled = $true
            return
        }

        $row   = $src.Rows[$e.RowIndex]
        $state = $row.Tag
        if (-not $state) { return }

        # Подсветка строки: красная - неправильный тип запуска, жёлтая - служба
        # остановлена, серая - службы нет в системе, обычная - всё в порядке.
        $backHex = $CLR.Panel
        $markHex = ''
        if (-not $state.Exists) { $backHex = $CLR.RowMissing }
        elseif ($state.ProblemKind -eq 'Startup') { $backHex = $CLR.RowProblem; $markHex = $CLR.Red }
        elseif ($state.ProblemKind -eq 'Stopped') { $backHex = $CLR.RowWarn;    $markHex = $CLR.Amber }

        $brush = New-Object System.Drawing.SolidBrush((Get-Color $backHex))
        try { $g.FillRectangle($brush, $e.CellBounds) } finally { $brush.Dispose() }
        if ($row.Selected) {
            $overlay = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(20, 255, 255, 255))
            try { $g.FillRectangle($overlay, $e.CellBounds) } finally { $overlay.Dispose() }
        }
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Line))
        try {
            $g.DrawLine($pen, $e.CellBounds.Left, ($e.CellBounds.Bottom - 1), $e.CellBounds.Right, ($e.CellBounds.Bottom - 1))
        }
        finally { $pen.Dispose() }

        switch ($e.ColumnIndex) {
            0 {
                if ($markHex) {
                    $markBrush = New-Object System.Drawing.SolidBrush((Get-Color $markHex))
                    try { $g.FillRectangle($markBrush, $e.CellBounds.X, $e.CellBounds.Y, 2, ($e.CellBounds.Height - 1)) }
                    finally { $markBrush.Dispose() }
                }

                $isChecked = $false
                try { $isChecked = [bool]$row.Cells[0].Value } catch { }
                $isEnabled = (-not $row.Cells[0].ReadOnly)

                $boxX = $e.CellBounds.X + [int](($e.CellBounds.Width - 15) / 2) + 1
                $boxY = $e.CellBounds.Y + [int](($e.CellBounds.Height - 15) / 2)

                $borderHex = $CLR.BoxBorder
                $fillHex   = ''
                if (-not $isEnabled) { $borderHex = $CLR.BoxBorder2; $fillHex = $CLR.BtnOffBg }
                elseif ($isChecked)  { $borderHex = $CLR.Accent;     $fillHex = $CLR.Accent }

                if ($fillHex) {
                    $boxBrush = New-Object System.Drawing.SolidBrush((Get-Color $fillHex))
                    try { $g.FillRectangle($boxBrush, $boxX, $boxY, 15, 15) } finally { $boxBrush.Dispose() }
                }
                $boxPen = New-Object System.Drawing.Pen((Get-Color $borderHex))
                try { $g.DrawRectangle($boxPen, $boxX, $boxY, 14, 14) } finally { $boxPen.Dispose() }

                if ($isChecked -and $isEnabled) {
                    $checkPen = New-Object System.Drawing.Pen((Get-Color $CLR.AccentFg), 2)
                    try {
                        $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
                        $checkPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
                        $checkPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                        $oldMode = $g.SmoothingMode
                        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                        $points = [System.Drawing.PointF[]]@(
                            (New-Object System.Drawing.PointF(($boxX + 3.5), ($boxY + 7.6))),
                            (New-Object System.Drawing.PointF(($boxX + 6.3), ($boxY + 10.5))),
                            (New-Object System.Drawing.PointF(($boxX + 11.4), ($boxY + 4.4)))
                        )
                        $g.DrawLines($checkPen, $points)
                        $g.SmoothingMode = $oldMode
                    }
                    finally { $checkPen.Dispose() }
                }
            }
            1 {
                $titleHex = '#A8ADB4'
                if ($state.IsProblem) { $titleHex = $CLR.Text }
                elseif (-not $state.Exists) { $titleHex = $CLR.Muted2 }
                Invoke-DrawText -Graphics $g -Text $state.DisplayName -Font $App.UI.Fonts.RowTitle -ColorHex $titleHex `
                    -Rect (New-Object System.Drawing.Rectangle(($e.CellBounds.X + 3), ($e.CellBounds.Y + 5), ($e.CellBounds.Width - 9), 17)) `
                    -Flags 'Left,Top,NoPrefix,EndEllipsis'
                Invoke-DrawText -Graphics $g -Text $state.Key -Font $App.UI.Fonts.Mono -ColorHex $CLR.Muted2 `
                    -Rect (New-Object System.Drawing.Rectangle(($e.CellBounds.X + 3), ($e.CellBounds.Y + 23), ($e.CellBounds.Width - 9), 15)) `
                    -Flags 'Left,Top,NoPrefix,EndEllipsis'
            }
            2 {
                $dotHex  = $CLR.Green
                $textHex = $CLR.Muted
                $text    = 'Не найдена'
                if (-not $state.Exists) { $dotHex = $CLR.Muted2; $textHex = $CLR.Muted2 }
                else {
                    $text = Get-StatusRu $state.CurrentStatus
                    if ($state.ProblemKind -eq 'Startup') { $dotHex = $CLR.Red;   $textHex = $CLR.RedText }
                    elseif ($state.ProblemKind -eq 'Stopped') { $dotHex = $CLR.Amber; $textHex = $CLR.AmberText }
                }
                Invoke-DrawDot -Graphics $g -ColorHex $dotHex -X ($e.CellBounds.X + 3) -Y ($e.CellBounds.Y + [int](($e.CellBounds.Height - 6) / 2)) -Size 6
                Invoke-DrawText -Graphics $g -Text $text -Font $App.UI.Fonts.RowText -ColorHex $textHex `
                    -Rect (New-Object System.Drawing.Rectangle(($e.CellBounds.X + 14), $e.CellBounds.Y, ($e.CellBounds.Width - 17), ($e.CellBounds.Height - 1))) `
                    -Flags 'Left,VerticalCenter,NoPrefix,EndEllipsis'
            }
            3 {
                $text    = '—'
                $textHex = $CLR.Muted3
                if ($state.Exists) {
                    $text = Get-StartupRu $state.CurrentStartup
                    if ($state.CurrentStartup -eq 'Disabled') { $textHex = $CLR.RedText }
                    elseif ($state.ProblemKind -eq 'Startup') { $textHex = $CLR.RedText }
                    elseif ($state.IsProblem) { $textHex = $CLR.Muted }
                }
                Invoke-DrawText -Graphics $g -Text $text -Font $App.UI.Fonts.RowText -ColorHex $textHex `
                    -Rect (New-Object System.Drawing.Rectangle(($e.CellBounds.X + 2), $e.CellBounds.Y, ($e.CellBounds.Width - 8), ($e.CellBounds.Height - 1))) `
                    -Flags 'Left,VerticalCenter,NoPrefix,EndEllipsis'
            }
            default {
                $textHex = $CLR.Muted3
                if ($state.IsProblem) { $textHex = $CLR.Text3 }
                # У строк, которые утилита не чинит, вместо описания - что делать игроку.
                $cellText = $state.Description
                if ($state.Hint) { $cellText = $state.Hint; $textHex = $CLR.AmberText }
                Invoke-DrawText -Graphics $g -Text $cellText -Font $App.UI.Fonts.RowText -ColorHex $textHex `
                    -Rect (New-Object System.Drawing.Rectangle(($e.CellBounds.X + 2), ($e.CellBounds.Y + 3), ($e.CellBounds.Width - 8), ($e.CellBounds.Height - 8))) `
                    -Flags 'Left,VerticalCenter,NoPrefix,WordBreak'
            }
        }

        $e.Handled = $true
    })

    # Галочка должна применяться сразу, а не после ухода фокуса.
    $grid.Add_CurrentCellDirtyStateChanged({
        param($src, $e)
        if ($src.IsCurrentCellDirty) {
            $src.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })

    $grid.Add_CellValueChanged({
        param($src, $e)
        if ($App.Populating) { return }
        if ($e.RowIndex -lt 0) { return }
        $src.InvalidateRow($e.RowIndex)
        Update-Selection
    })

    # Клик по любому месту строки тоже переключает галочку - так удобнее.
    $grid.Add_CellClick({
        param($src, $e)
        if ($App.Running) { return }
        if ($e.RowIndex -lt 0 -or $e.ColumnIndex -le 0) { return }
        $cell = $src.Rows[$e.RowIndex].Cells[0]
        if ($cell.ReadOnly) { return }
        $cell.Value = (-not [bool]$cell.Value)
    })

    # --- нижняя панель ---
    $footer = New-Object System.Windows.Forms.Panel
    $footer.SetBounds(0, 552, 760, 46)
    $footer.BackColor = Get-Color $CLR.Bg
    $footer.Add_Paint({
        param($src, $e)
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border2))
        try { $e.Graphics.DrawLine($pen, 0, 0, $src.Width, 0) } finally { $pen.Dispose() }
    })
    $form.Controls.Add($footer)

    $chkAll = New-Object System.Windows.Forms.CheckBox
    $chkAll.Text      = 'Выбрать все'
    $chkAll.Font      = $fonts.Button
    $chkAll.ForeColor = Get-Color $CLR.Text3
    $chkAll.BackColor = Get-Color $CLR.Bg
    $chkAll.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $chkAll.FlatAppearance.BorderSize = 0
    $chkAll.SetBounds(18, 13, 140, 20)
    $chkAll.Cursor    = [System.Windows.Forms.Cursors]::Hand
    $footer.Controls.Add($chkAll)
    $App.UI.ChkAll = $chkAll

    # «Выбрать все» не должен ставить галочки на недоступных строках.
    $chkAll.Add_CheckedChanged({
        param($src, $e)
        if ($App.Suppress -or $App.Running) { return }
        $grid = $App.UI.Grid
        $App.Populating = $true
        try {
            foreach ($row in $grid.Rows) {
                $state = $row.Tag
                if ($state -and $state.CanFix) { $row.Cells[0].Value = [bool]$src.Checked }
            }
        }
        finally { $App.Populating = $false }
        $grid.Invalidate()
        Update-Selection
    })

    $btnFix = New-FlatButton -Text 'Включить выбранные службы' -X 536 -Y 6 -Width 208 -Height 34 -Primary -Font $fonts.ButtonMain
    $btnFix.Add_Click({ Invoke-FixSelected })
    $footer.Controls.Add($btnFix)
    $App.UI.BtnFix = $btnFix

    $btnReport = New-FlatButton -Text 'Сохранить отчёт' -X 404 -Y 7 -Width 124 -Height 32 -Font $fonts.Button
    $btnReport.Add_Click({ Invoke-SaveReport })
    $footer.Controls.Add($btnReport)
    $App.UI.BtnReport = $btnReport

    $btnRefresh = New-FlatButton -Text 'Обновить' -X 304 -Y 7 -Width 92 -Height 32 -Font $fonts.Button
    $btnRefresh.Add_Click({ Invoke-Scan })
    $footer.Controls.Add($btnRefresh)
    $App.UI.BtnRefresh = $btnRefresh

    # --- строка состояния ---
    $status = New-Object System.Windows.Forms.StatusStrip
    $status.Dock       = [System.Windows.Forms.DockStyle]::Bottom
    $status.AutoSize   = $false
    $status.Height     = 22
    $status.SizingGrip = $false
    $status.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System
    $status.BackColor  = Get-Color $CLR.Chrome
    $status.Padding    = New-Object System.Windows.Forms.Padding(8, 0, 8, 0)

    # StatusStrip плохо поддаётся перекраске: штатный отрисовщик рисует свой фон
    # поверх BackColor. Поэтому, помимо RenderMode = System, красим и сами надписи -
    # левая растянута на всю свободную ширину, так что полоса остаётся тёмной
    # даже если отрисовщик проигнорирует цвет самой панели.
    $statusLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLeft.Spring    = $true
    $statusLeft.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $statusLeft.ForeColor = Get-Color $CLR.Muted
    $statusLeft.BackColor = Get-Color $CLR.Chrome
    $statusLeft.Font      = $fonts.Status
    $statusLeft.Text      = 'Запуск...'

    $statusRight = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusRight.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $statusRight.ForeColor = Get-Color '#5C5F66'
    $statusRight.BackColor = Get-Color $CLR.Chrome
    $statusRight.Font      = $fonts.Status
    $statusRight.Text      = "Администратор   $SCRIPT_VERSION"

    $status.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($statusLeft, $statusRight))
    $form.Controls.Add($status)
    $App.UI.Status     = $status
    $App.UI.StatusLeft = $statusLeft

    # --- запуск ---
    # Пока идёт исправление, окно закрывать нельзя: DoEvents пропускает клики
    # внутрь цикла, и закрытие на середине уронило бы процесс на уже
    # уничтоженных элементах управления, оставив службы наполовину починенными.
    $form.Add_FormClosing({
        param($src, $e)
        if ($App.Running) {
            $e.Cancel = $true
            Set-StatusText 'Идёт включение служб — дождись окончания'
        }
    })

    $form.Add_Shown({ Invoke-Scan })

    try {
        $form.ShowDialog() | Out-Null
    }
    finally {
        $form.Dispose()
        foreach ($font in $fonts.Values) { $font.Dispose() }
        $App.UI.Fonts = $null
    }
}

# --- Точка входа ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch { }

$App.IsAdmin = Test-Admin

if ($App.IsAdmin) {
    Show-MainWindow
}
else {
    # Изменение служб требует прав администратора - перезапускаем сами себя.
    # Если игрок нажал «Нет» в окне контроля учётных записей, показываем
    # понятное окно с кнопкой «Перезапустить от имени администратора».
    if (-not (Invoke-Elevate)) {
        $App.UI.Fonts = New-AppFonts
        try { Show-NoAdminWindow }
        finally {
            foreach ($font in $App.UI.Fonts.Values) { $font.Dispose() }
            $App.UI.Fonts = $null
        }
    }
    # Копия уже работает от администратора - этот процесс больше не нужен.
    exit
}
