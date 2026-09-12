<#
    RuRBW Service Restorer
    Включает обратно системные службы Windows, которые вырубают «твикеры»,
    из-за чего на ScreenShare прилетает бан за Disabled Services.

    Проект : Russian Ranked Bedwars, rrbw.pro
    Автор  : @slurov
    Версия : 1.0.3
    Лицензия: MIT

    Запуск одной строкой в cmd:
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/slurov/rurbw-service-restorer/v1.0.3/fix.ps1 | iex"

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

    Три длинные строки base64 ниже ($IMG_...) - это картинки интерфейса:
    логотип сервера и значок Discord. Не код, выполниться они не могут.
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
$SCRIPT_URL     = 'https://raw.githubusercontent.com/slurov/rurbw-service-restorer/v1.0.3/fix.ps1'
$SCRIPT_VERSION = 'v1.0.3'
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
    WindowBd   = '#101114'   # рамка окна
    TitleBar   = '#1E1F22'   # собственный заголовок окна
    TitleLine  = '#131416'
    TitleText  = '#B5BAC1'
    TitleHover = '#35373C'
    CloseHover = '#C02C3C'
    MaxOff     = '#55585E'
    AccentHov  = '#BC2D41'
    AccentDown = '#962334'
    AccentLine = '#B13D4E'
    BtnDown    = '#4D4F55'
    Spinner    = '#C9394F'
    Lock       = '#E0797B'
    ModalText  = '#A8ADB4'
    StatusRight= '#5C5F66'
    Thumb      = '#1E1F22'   # ползунок прокрутки
}

# Картинки интерфейса: логотип сервера (36 и 16 px) и значок Discord (13 px).
# Это PNG в base64 - картинки, а не код: они попадают только в Image.FromStream
# и выполниться не могут. Посмотреть, что внутри, можно так:
#   [IO.File]::WriteAllBytes("$env:TEMP\logo.png", [Convert]::FromBase64String($IMG_LOGO36))
# и открыть получившийся файл.
$IMG_LOGO36  = 'iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAArqSURBVFhHjZgJUFRXFoa7aibJZJZyARTopjdooFe2tqVliUtMMtknyVTMokajRAVkUZB9B0XoBtEO4JZAYjTGzCQukzFiRsUVRE1iEkQBIXFBEQFZFMV/6tzHg0eHTA1Vf93Le/f1/d5/zrn3dotEIpFo37p9j5aHPrdgQ9DTG6ymmTareZbNYgxdR/3iwCfXF/qHllgDqT9rvcU0ne7ZqKX77H92jdqZNkvgTFuBMdSW709jZtpWG0NtOX5BrM3zD/mV1gY8saHQPGsBvsHviEXUsG7dowW+QactHn7Ik+uR46ZBnlyHfA8/rHH3Zcr3oNaHafWQWF/JKW9YBuQKpTAgXaZFmr2kWqRKNUzUp7FZOtPR8zt3PiIqCX5qEcHkeAXAEhCKf85fhqIpM5AqVSNTaUDGkNKVemQo9UhXjFaaQodUhQ4pQ22qfEh0Ta7DKqka8VI14ty8EeemRrwb3+fFXctRGlBgnv26yGKavjFb7I3tr81HbW4RzhbYsPWZV5HqxgGRCIYBDUPokUJvp9APT0yyB0qWaxmMUEKYkWtq5lauX1CxyBo4y5Yr16HYNAMnMwvwrbUMVdHJbPIMhW7IJT2zOmGSkkGkKfXIVhtZyyDGcIecGwvIXgS20s2bvWCOf4iFHLLlKQzI8vDFnsXRqHzxDRSZZjIA5g454KZGfkAodselIt5RjnSVL45Ybcjy8keqTDsaSADIh0wYNnsYXuRQtl+wVVRgnG6jxKWJ0yjR3Egj+UOhSnRRIVmuQ/W6MhQ98VdseuUtHCkoQTzvmNAlO7cSZZrRrgjyiJzhxYB8g60iKt18d18OQMHlDB+mVZOU+CopC58tiUGCVI3Grw6i90ITbhytQcuer5FEVlPVjAU1BDRW2HhXRgHJtMjxDbGIrObZzCEeQpjIyVINEpV6/CfHgltHa9FRXYPeU9+i78RZnC+twCpXFWLHiRHnIBulVZPdkSxVD+dSkkzLEnd0dY3A8CFjOcSFzGe4pClMBMQqSa5D9CQFUrz80bL9CzRV7sK+ZSux2i8EKWojyl55Cx/ODcOHby9mqpgbhq1vLMS6mc+zZwk22c2bJT+Fjoewd4dEL5/tG2QR0QpMQKy0GRBX4jxQgkyDKGd3ZOkCkejhg9wZz2Lv2mJc+6kBv/X38N4A2uobsD+vkE2U4OLBOS7XsgS3B1oxVGXZvtOsokLTjPeFDvHrDJ8LZHekgwzZ5lm4XHcOuD/IzTr4EIO9/Rjs6cNg75Co39OHh/13gYfcsMZDR5GmNCBJ4jWcZwRGjiVINVhFwFINshR6rDWGWkRrDGbLGg+qstErr7B0w8eJseWtRWyCB909uH+7C/c7OjHY3cNNTCLOQeBhbz+7x6mLPVNdUoaY8ZLhBZQXgdELJ8k0yJTrsJrKfq1/cAntTfbOCKslcoIEm/4+D+jtx0B7BwZu3sKD213ovtSM2k2VqNlYwXRm6zZ0/nQRDzq7ce/GLTZusKsHnQ1NyFAbkSDxsgPhnCJlyHVYQ0ltnTZ7M22K9jDDe5RchwgCem0e0HkH967dwN1rbUDXHTRXHcE7jzth/uNOeOdPkzH39+Nhnf4s7v58FQM3buHu1Tbcu34Tg+23sf6pl7HCScFg+JDxopBlyHTIJYdW66cV005tDzIqZBMk2Pjq23jY1o6+y7+gr7kVD663o/nrQ4h09sByFw9EuXrivUkKRDopcPXwCdy/egN9Ta3ov/wLHly7idIXXkeMo2yUKxwMt5LTqYAl9WqD2UpHCAYiHwtIy4DKX34TD36+ht6GZvRcaMLAz9fQtPcAwv/sjIi/uCBynBgLH5mAXPOT6PnpEvoutbBxvRcvo//iZRSGPoPYSYoRkOGk5oBoq8qhss83TLNSDtmD8O6QveET3BjQQGMr7vzQgDvnL6C3vhFtx2rx75QcTsk5+DozH1cOHUd/QzPunOfG3W1sxS8HDiNeqkG82GsUDA9EqzcHFGLhHHLnQjZ8hBgL6MU5uPvjJXSdOY+uuu/Refo7dJ/9AfcvteD+xRYMXOTa3u/q2T3+/sPmK9ixeDmWjhOz8NiDcFsJd/xgK3W+X8ioHLIXA5rohrLnX0fvmR9w+8QZdBw/jY7jdUz0/23qHyOdHtHxOnTXnENVah7CHWVYIfYctfMLD2r8Sp2hN5eI1voGWX7LIf5MEzFRitJnX8OdU+dw68gp3Dp8Cu2HT6KjuhY9J8+h59Q5dJ04y661HzqJW4dPoq/uPHbHJGH+Yw6IcvFgEPau8DCxEi8k0QnDZ1qRKD8gdH22Qj88WNhSRTAgBylsT/8NXdW1aD94DDerjqKzuhb1FTtRMvslFE1/DlUJWeg+Vsfu3aw6xsZ+v+UTVoGxrqpfnYv4LWOFxIsBJRKQwWwRZfmY11H8+E1vrJ146UQpNjz5EjoOVKNt3ze4vvcgbh88jrqicsz94yS88QcHJCkNaNnxJdr3H2H3r++pQvehU6h8cxHCx4s5GIErPAgpRuyJBIk3UrVTLKJMtdFCGS6EEYoeDJsgQcmsF3H9ywNo3bkXLZ/uxvXdB1BTsAERk5VY5uyOsPFifPHucrTtqULLjt1MVz7/Fy5s3YFEdwNiXVQCmBEggomm/JJ4cw7lGUNLySF7EN4dBjTRDcXTn0Pr9i/RWLkLjZWfofXT3TieXYgYConYE+85yZHq6Yf68o/QvO0fuFSxExc/+BRXdu3D9nlL2Fo2ljMEEyX2RDw5pDMViTLVUyx0WrMPFS96MGyiFNaQZ9BUsRMNWz5B/aaP0VjxGarT1mCFqwpxEi9EuqqYk5/PX4bmj3ahfuPHqN/4ERo2f4IfyyqRppuK5ZOVQyCjYZbTZ4i9kKqbahFl6aeW8ED2MMNADjIUBM7CubUb2Fcl/uvS/qhEVs70LBvnJEe6dwBqsgpxOq8YtTlWpu+sZdg2511W/gTDg3AwnuxlVvJAmTpTEeWQPQgvsjjCRYUI+iCZFtFyLWLkOqY4uY6NocqhNsJVhSXO7oiSqrmxw+O1iHf3YSDkDMu7SQpEOLszGB4oSW0qFKWrjRa+ysYSAdGbvOfsjgVOcsx3lOMdRznbSKmkhUA04RIXj+FxvBY6ybFkspKFJtLFA1m+QXRcRTS9rKuKKVbshWRyKMc/uJQO5PYgQiB6q6ihB8NdOJH1dJ/Cxa8tFDaCpzemMcsEomfp+hIHGbbNWYjTuUXYvSgKKxV6LJnsjhhXTyRqplhFaeoAK51n7UGEYoko4WLPx58HYd+zBIudffUwV1xVrA13dscKuRb7IxNwsbwSXyyKwtLJShZmDmiqleXQ/wLiVlNuIh6MJAQaWV+8BOuLffIOuST2xOqpM7H5hTlsOwpzUmCpiweiXT2RojNbqcre/y0g4QRCGHKAWyb+fxhyiYXcVYXFDjKEOcqx2FHGYCjvCChZayoW5fmHzKMTP7kwGsZuERPAjAD9eqwwXHw+8YnL5yDlFIHwMFQwcRI1UnyDXxV9k5b2WIbGWJMl576pMrlp2GbHK8HNm4mWd1pR2b7DxqrZLk1i4yQjY6iMSbGunkPyYnlCTkS7qliR0LF3uYsKKyVqxHn5n9gXGfko+xWNfrnKN4YuyNGbbZm6QFu6zmTL9DFvStdP3cT3U7SmslSN0UZtrl/wVhqXqQssT2cy2dg9Xtoppek+5g+SNEZbqiFwS7I+cDP1E7TG8lVqYymJ+vHe/rZEjen9NEPw26jF74nlv25bRODMu/qrAAAAAElFTkSuQmCC'
$IMG_LOGO16  = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAANESURBVDhPRdJ7aFtVHAfw+5/gXwWX1CY395Xc3PdtSFtK5phTh7IN3UQFmcL+0T1q0zaPmybeNs/W+dgfkxbG1D/cJj5G2WDQuofQIbZg2tykY64b+FZERGFuY24W/Mo56fTCl/O48OH8fucwb8Q3bnpT61ucVHu9CbWnQVJTe7ya0uORsUqixL2yEvfcSIxmLBLzqtH4Qs1IJJiqHG/NH8jiw50voMyqqAkmSkEVFd5ERbJQFixURAtFwUSB01AItVPiDLiR7jpTlmMrx7c/h+lNT6DI6Zgw+zG19Skc2fYM3JCGccHEuGjCFQzkOK2dkIY8gcLdDWZS6/XKrAY3EMWkncDZQgW/zS/i9P40kvdtgPMAj0wHS8c8p8MJqciG1HXArjM1UrtkoyxZyD4Yxju7duNc6SC+ePcYvpo7jyufXsDyRzM49uJLyHWGMcppFCGAGyGAEl+uSTY9puMT8dajO3Dn+g3Q76+7wN219hzAiT376ElIOeO8gaIcqzNVpcerihYFsj4BR3Y+D9y8jZvf/IBq3xYM+iVcnjlDAe/4xxjpYPEqr1NgjDSxIsfq/wMiprc/i7Uff8H1S6s4ums3Xt+4FVdPzwK37uDzQ9MY6ggiz+twOb1dQjUaX6pKNooE8EuYevxp3GpdwZ9LK/jn65+wdu073L50Fd+fOY+J3s1Ir/eBXmfYXmKKcmx5jDeomvaLePuxJ3FjoYFfz17EyX0prL7/Cf5urWLWKWHv/T6M8jq9hRyrIidadaYg2ctEI5uDG3gc2rwNv8/N49sPTmFvRxCHH9mBP+Yu4ueZWRzsexjDfhFpVkGWRDDaALkSAiT9Iib7tuDy1Hv48rXDcOUYBnwCPnNKuHb0BE69PIxBn0AbmwrISAt6ncmL5n9AhlWRDEaRJOWsv7zhLhkHAjLdS0kWUiEVFTuBLPnHaRTw7gEkI8EoXumUMBKQKUD2hroiGOiUsN8nwAnbuJByUTT6MdAlN5iCZDXGOR2jIa3dGFaFwyr0pZHcW2eCUYoOB6LIiiYyQQVDvF5nSnr/Q8Vw92JBspo5yWo5otl0BKOVD9utnETnXkY0m2nBWEkJemuI05pJVmmmOWMhF+1N/AuJCQPFF54aCQAAAABJRU5ErkJggg=='
$IMG_DISCORD = 'iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAADUSURBVChTvZExaoJBEIV/JBAFyWlyhTRa2OgJxMYihIhgYyVop0ewsbOwkhTiCWxCChESsdJL/Oz3ZGQWf0TQQvKa4c1+b2fYTZJHCMhblZTz+nzJnCTpCegC38BW0gr49foH/Ni5pHMIaOkOAc04pQAcLoFrAvbG25RypmmrfAJr91v3m8ikaVpJQgiDTOjd1627//BtGpEJIQwNmGRCC+AV+HK/dD/PMFMLzWLjHtmFFnrzZ74pYAeU4pMXgTbQl1QFhpLGwAioAT2gI+nl/FH/oSNY56DllidCVgAAAABJRU5ErkJggg=='

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
    @{ Key='PcaSvc'; AltNames=@(); DisplayName='Помощник совместимости'
       Target='AutomaticDelayed'; TargetWin10='Manual'; Kind='Service'; Critical=$false
       Description='Записывает, какие программы запускались на компьютере' }

    @{ Key='DPS'; AltNames=@(); DisplayName='Политика диагностики'
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
    @{ Key='CDPSvc'; AltNames=@(); DisplayName='Подключённые устройства'
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

    @{ Key='DcomLaunch'; AltNames=@(); DisplayName='Модуль запуска DCOM'
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
    @{ Key='bam'; AltNames=@(); DisplayName='Активность приложений'
       Target='System'; Kind='Driver'; Critical=$false
       Description='Записывает, когда и какие программы запускались' }

    @{ Key='dam'; AltNames=@(); DisplayName='Активность рабочего стола'
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
        'Не удалось загрузить утилиту: ' + `$_.Exception.Message + [Environment]::NewLine + [Environment]::NewLine + 'Проверьте интернет и запустите команду заново.',
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
# Цвет из строки вида #RRGGBB; готовый цвет возвращается как есть.
function Get-Color {
    param($Value)
    if ($Value -is [System.Drawing.Color]) { return $Value }
    return [System.Drawing.ColorTranslator]::FromHtml([string]$Value)
}

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
        $state.Hint = 'Критическая служба, утилита её не меняет. Включите вручную через services.msc'
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
    $lines.Add(' Russian Ranked Bedwars — rrbw.pro | by @slurov')
    $lines.Add($rule)

    Set-Content -LiteralPath $path -Value $lines -Encoding UTF8 -ErrorAction Stop
    return $path
}

# --- Интерфейс: общие части ---
# Размеры шрифтов - в пикселях, ровно как в макете. Создаём один раз, в конце освобождаем.
function New-UiFont {
    param([double]$Px, [switch]$Semibold, [switch]$Mono)
    $family = 'Segoe UI'
    if ($Mono) { $family = 'Consolas' } elseif ($Semibold) { $family = 'Segoe UI Semibold' }
    $font = New-Object System.Drawing.Font($family, [single]$Px, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    # Если полужирного начертания в системе нет, .NET молча подставит другой шрифт.
    if ($Semibold -and $font.Name -ne 'Segoe UI Semibold') {
        $font.Dispose()
        $font = New-Object System.Drawing.Font('Segoe UI', [single]$Px, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    }
    return $font
}

function New-AppFonts {
    return @{
        Base         = New-UiFont 12
        TitleBar     = New-UiFont 12
        Header       = New-UiFont 15.5 -Semibold
        Link         = New-UiFont 12
        Badge        = New-UiFont 11.5
        Author       = New-UiFont 11
        SummaryTitle = New-UiFont 18 -Semibold
        SummaryText  = New-UiFont 12.5
        SummaryHint  = New-UiFont 11.5
        ProgressTop  = New-UiFont 14 -Semibold
        Counter      = New-UiFont 12
        MonoLine     = New-UiFont 12 -Mono
        Section      = New-UiFont 11
        Hint         = New-UiFont 11.5
        GridHead     = New-UiFont 11
        RowTitle     = New-UiFont 13 -Semibold
        RowId        = New-UiFont 11 -Mono
        RowText      = New-UiFont 12
        SelectAll    = New-UiFont 12.5
        Button       = New-UiFont 12.5
        ButtonMain   = New-UiFont 13 -Semibold
        ModalBtnMain = New-UiFont 12.5 -Semibold
        Status       = New-UiFont 11.5
        ModalTitle   = New-UiFont 15.5 -Semibold
        ModalText    = New-UiFont 13
        ModalNote    = New-UiFont 12
        NoAdminTitle = New-UiFont 19 -Semibold
        Code         = New-UiFont 11.5 -Mono
    }
}

# Картинку из base64 сразу копируем в отдельный Bitmap: Image.FromStream требует,
# чтобы поток жил столько же, сколько картинка, а держать его открытым незачем.
function ConvertFrom-Base64Image {
    param([string]$Base64)
    $stream = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String($Base64))
    try {
        $image = [System.Drawing.Image]::FromStream($stream)
        try { return (New-Object System.Drawing.Bitmap($image)) } finally { $image.Dispose() }
    }
    finally { $stream.Dispose() }
}

function New-AppImages {
    return @{
        Logo36  = ConvertFrom-Base64Image $IMG_LOGO36
        Logo16  = ConvertFrom-Base64Image $IMG_LOGO16
        Discord = ConvertFrom-Base64Image $IMG_DISCORD
    }
}

function Remove-AppResources {
    foreach ($key in @('Fonts', 'Images')) {
        $set = $App.UI[$key]
        if ($set) { foreach ($item in $set.Values) { try { $item.Dispose() } catch { } } }
        $App.UI[$key] = $null
    }
}

# Двойная буферизация убирает мерцание. Свойство у WinForms защищённое,
# поэтому включаем его через отражение - обычный приём для самописной отрисовки.
function Enable-DoubleBuffer {
    param($Control)
    try {
        $property = [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'Instance,NonPublic')
        $property.SetValue($Control, $true, $null)
    }
    catch { }
}

# Цвет поверх фона с прозрачностью (как opacity в CSS).
function Get-Blend {
    param($Fore, $Back, [double]$Alpha)
    $f = Get-Color $Fore; $b = Get-Color $Back
    return [System.Drawing.Color]::FromArgb(
        [int]($b.R + ($f.R - $b.R) * $Alpha), [int]($b.G + ($f.G - $b.G) * $Alpha), [int]($b.B + ($f.B - $b.B) * $Alpha))
}

function Get-TextWidth {
    param([string]$Text, $Font)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, [System.Drawing.Size]::Empty,
        [System.Windows.Forms.TextFormatFlags]'NoPadding,NoPrefix,SingleLine').Width
}

function Get-GlyphHeight {
    param($Font)
    return [System.Windows.Forms.TextRenderer]::MeasureText('Ay', $Font, [System.Drawing.Size]::Empty,
        [System.Windows.Forms.TextFormatFlags]'NoPadding,NoPrefix,SingleLine').Height
}

# Одна строка текста, выровненная внутри строки высотой LineHeight (как line-height в CSS).
function Invoke-DrawLine {
    param($Graphics, [string]$Text, $Font, $Color, [double]$X, [double]$Top, [double]$LineHeight = 0,
          [string]$Align = 'Left', [int]$MaxWidth = 0)
    if ([string]::IsNullOrEmpty($Text)) { return }
    $glyph = Get-GlyphHeight $Font
    if ($LineHeight -le 0) { $LineHeight = $glyph }
    $y = [int][Math]::Round($Top + ($LineHeight - $glyph) / 2)
    $flags = [System.Windows.Forms.TextFormatFlags]'NoPadding,NoPrefix,SingleLine'
    $width = Get-TextWidth $Text $Font
    if ($MaxWidth -gt 0 -and $width -gt $MaxWidth) {
        $rect = New-Object System.Drawing.Rectangle([int]$X, $y, $MaxWidth, $glyph)
        [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $Font, $rect, (Get-Color $Color),
            ($flags -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis))
        return
    }
    $left = $X
    if ($Align -eq 'Right') { $left = $X - $width } elseif ($Align -eq 'Center') { $left = $X - $width / 2 }
    [System.Windows.Forms.TextRenderer]::DrawText($Graphics, $Text, $Font,
        (New-Object System.Drawing.Point([int][Math]::Round($left), $y)), (Get-Color $Color), $flags)
}

# Перенос по словам. Свой, а не флаг WordBreak: GDI на системах с кодовой
# страницей UTF-8 (65001) рвёт кириллические слова посередине.
function Split-TextLines {
    param([string]$Text, $Font, [int]$Width)
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($paragraph in ($Text -split "`r?`n")) {
        $current = ''
        foreach ($word in ($paragraph -split ' ')) {
            $candidate = if ($current) { "$current $word" } else { $word }
            if ((Get-TextWidth $candidate $Font) -le $Width) { $current = $candidate; continue }
            if ($current) { $lines.Add($current); $current = '' }
            # Слово длиннее строки (например, путь к файлу) режем по буквам.
            while ($word.Length -gt 1 -and (Get-TextWidth $word $Font) -gt $Width) {
                $cut = $word.Length - 1
                while ($cut -gt 1 -and (Get-TextWidth $word.Substring(0, $cut) $Font) -gt $Width) { $cut-- }
                $lines.Add($word.Substring(0, $cut))
                $word = $word.Substring($cut)
            }
            $current = $word
        }
        $lines.Add($current)
    }
    return , $lines
}

function Invoke-DrawLines {
    param($Graphics, $Lines, $Font, $Color, [double]$X, [double]$Top, [double]$LineHeight, [string]$Align = 'Left')
    $y = $Top
    foreach ($line in $Lines) {
        Invoke-DrawLine -Graphics $Graphics -Text $line -Font $Font -Color $Color -X $X -Top $y -LineHeight $LineHeight -Align $Align
        $y += $LineHeight
    }
}

# Текст с разрядкой (letter-spacing в CSS) - для подписей капсом.
# Место буквы считаем по ширине куска слова перед ней, а не складываем ширины
# отдельных букв. Плюс GDI добавляет к каждому замеру постоянный запас в пару
# пикселей - его вычитаем, иначе после первой буквы слова появляется щель.
function Invoke-DrawSpaced {
    param($Graphics, [string]$Text, $Font, $Color, [double]$X, [double]$Top, [double]$LineHeight, [double]$Spacing)
    $pad        = 2 * (Get-TextWidth 'a' $Font) - (Get-TextWidth 'aa' $Font)
    $spaceWidth = (Get-TextWidth 'a a' $Font) - (Get-TextWidth 'aa' $Font)
    $wordLeft = $X
    foreach ($word in ($Text -split ' ')) {
        for ($i = 0; $i -lt $word.Length; $i++) {
            $offset = 0
            if ($i -gt 0) { $offset = (Get-TextWidth $word.Substring(0, $i) $Font) - $pad }
            Invoke-DrawLine -Graphics $Graphics -Text ([string]$word[$i]) -Font $Font -Color $Color `
                -X ($wordLeft + $offset + $i * $Spacing) -Top $Top -LineHeight $LineHeight
        }
        $wordLeft += (Get-TextWidth $word $Font) - $pad + $word.Length * $Spacing + $spaceWidth + $Spacing
    }
}

# Контур прямоугольника со скруглёнными углами.
# Имена переменных внутри нарочно не пересекаются с параметрами: в PowerShell
# регистр в именах не важен, и локальная $r молча затёрла бы радиус $R.
function New-RoundedPath {
    param([double]$X, [double]$Y, [double]$W, [double]$H, [double]$R, [switch]$TopOnly)
    $path     = New-Object System.Drawing.Drawing2D.GraphicsPath
    $left     = [single]$X
    $top      = [single]$Y
    $right    = [single]($X + $W)
    $bottom   = [single]($Y + $H)
    $diameter = [single]($R * 2)
    if ($R -le 0) {
        $path.AddRectangle((New-Object System.Drawing.RectangleF($left, $top, [single]$W, [single]$H)))
        return $path
    }
    $path.AddArc($left, $top, $diameter, $diameter, [single]180, [single]90)
    $path.AddArc([single]($right - $diameter), $top, $diameter, $diameter, [single]270, [single]90)
    if ($TopOnly) {
        $path.AddLine($right, [single]($top + $R), $right, $bottom)
        $path.AddLine($right, $bottom, $left, $bottom)
    }
    else {
        $path.AddArc([single]($right - $diameter), [single]($bottom - $diameter), $diameter, $diameter, [single]0, [single]90)
        $path.AddArc($left, [single]($bottom - $diameter), $diameter, $diameter, [single]90, [single]90)
    }
    $path.CloseFigure()
    return $path
}

# Скруглённый прямоугольник со сглаживанием: заливка и рамка в 1 пиксель.
function Invoke-FillRounded {
    param($Graphics, [double]$X, [double]$Y, [double]$W, [double]$H, [double]$R, $Fill, $Border, [switch]$TopOnly)
    $oldMode = $Graphics.SmoothingMode
    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    # С рамкой - полпикселя внутрь, иначе линия в 1 пиксель размазывается на два.
    $inset = 0
    if ($Border) { $inset = 0.5 }
    $path = New-RoundedPath -X ($X + $inset) -Y ($Y + $inset) -W ($W - 2 * $inset) -H ($H - 2 * $inset) -R $R -TopOnly:$TopOnly
    try {
        if ($Fill) { $brush = New-Object System.Drawing.SolidBrush((Get-Color $Fill)); try { $Graphics.FillPath($brush, $path) } finally { $brush.Dispose() } }
        if ($Border) { $pen = New-Object System.Drawing.Pen((Get-Color $Border)); try { $Graphics.DrawPath($pen, $path) } finally { $pen.Dispose() } }
    }
    finally { $path.Dispose(); $Graphics.SmoothingMode = $oldMode }
}

function Invoke-FillRect {
    param($Graphics, $Color, [double]$X, [double]$Y, [double]$W, [double]$H)
    $brush = New-Object System.Drawing.SolidBrush((Get-Color $Color))
    try { $Graphics.FillRectangle($brush, [single]$X, [single]$Y, [single]$W, [single]$H) } finally { $brush.Dispose() }
}

# Цветной кружок-индикатор.
function Invoke-DrawDot {
    param($Graphics, $Color, [double]$X, [double]$Y, [double]$Size = 6)
    $brush = New-Object System.Drawing.SolidBrush((Get-Color $Color))
    $oldMode = $Graphics.SmoothingMode
    try {
        $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $Graphics.FillEllipse($brush, [single]$X, [single]$Y, [single]$Size, [single]$Size)
    }
    finally { $Graphics.SmoothingMode = $oldMode; $brush.Dispose() }
}

# Картинка пиксель в пиксель, без размытия.
function Invoke-DrawImage {
    param($Graphics, $Image, [int]$X, [int]$Y, $Attributes = $null)
    $oldInterp = $Graphics.InterpolationMode; $oldOffset = $Graphics.PixelOffsetMode
    $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $Graphics.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    try {
        $rect = New-Object System.Drawing.Rectangle($X, $Y, $Image.Width, $Image.Height)
        if ($Attributes) { $Graphics.DrawImage($Image, $rect, 0, 0, $Image.Width, $Image.Height, [System.Drawing.GraphicsUnit]::Pixel, $Attributes) }
        else { $Graphics.DrawImage($Image, $rect, 0, 0, $Image.Width, $Image.Height, [System.Drawing.GraphicsUnit]::Pixel) }
    }
    finally { $Graphics.InterpolationMode = $oldInterp; $Graphics.PixelOffsetMode = $oldOffset }
}

# Одноцветный значок нужным цветом: он хранится белым и перекрашивается матрицей цвета.
function Invoke-DrawTinted {
    param($Graphics, $Image, [int]$X, [int]$Y, $Color)
    $c = Get-Color $Color
    $matrix = New-Object System.Drawing.Imaging.ColorMatrix
    $matrix.Matrix00 = 0; $matrix.Matrix11 = 0; $matrix.Matrix22 = 0
    $matrix.Matrix40 = $c.R / 255; $matrix.Matrix41 = $c.G / 255; $matrix.Matrix42 = $c.B / 255
    $attributes = New-Object System.Drawing.Imaging.ImageAttributes
    try { $attributes.SetColorMatrix($matrix); Invoke-DrawImage -Graphics $Graphics -Image $Image -X $X -Y $Y -Attributes $attributes }
    finally { $attributes.Dispose() }
}

# Флажок из макета: 15x15, скругление 2, белая галочка на фирменном красном.
function Invoke-DrawCheckBox {
    param($Graphics, [double]$X, [double]$Y, [bool]$Checked, [bool]$Enabled, [double]$Opacity = 1, $Surface = $CLR.Panel)
    if (-not $Enabled) { $border = $CLR.BoxBorder2; $fill = $CLR.BtnOffBg }
    elseif ($Checked)  { $border = $CLR.Accent;     $fill = $CLR.Accent }
    else               { $border = $CLR.BoxBorder;  $fill = $null }
    if ($Opacity -lt 1) {
        $border = Get-Blend $border $Surface $Opacity
        if ($fill) { $fill = Get-Blend $fill $Surface $Opacity }
    }
    Invoke-FillRounded -Graphics $Graphics -X $X -Y $Y -W 15 -H 15 -R 2 -Fill $fill -Border $border
    if (-not ($Checked -and $Enabled)) { return }
    # Та же галочка, что в макете: M5 12.5 l4.5 4.5 L19 7 в квадрате 10x10 по центру.
    $pen = New-Object System.Drawing.Pen((Get-Color $CLR.AccentFg), 1.5)
    $oldMode = $Graphics.SmoothingMode
    try {
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $Graphics.DrawLines($pen, [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF([single]($X + 4.6), [single]($Y + 7.7))),
            (New-Object System.Drawing.PointF([single]($X + 6.5), [single]($Y + 9.6))),
            (New-Object System.Drawing.PointF([single]($X + 10.4), [single]($Y + 5.4)))))
    }
    finally { $Graphics.SmoothingMode = $oldMode; $pen.Dispose() }
}

# Кнопка из макета (скругление 4, свои цвета наведения). Рисуем её сами поверх
# обычной Button - так сохраняется поведение кнопки: фокус, Enter, Esc, Enabled.
function New-UiButton {
    param([string]$Text, [string]$Kind = 'normal', $Font, [int]$PadX = 13, [int]$Height = 35, $Surface = $CLR.Bg)
    $button = New-Object System.Windows.Forms.Button
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.UseVisualStyleBackColor = $false
    $button.BackColor = Get-Color $Surface
    $button.Font = $Font
    $button.Text = $Text
    $button.TabStop = $true
    $button.Tag = @{ Kind = $Kind; Hover = $false; Down = $false; PadX = $PadX; Surface = $Surface }
    $button.Size = New-Object System.Drawing.Size(((Get-TextWidth $Text $Font) + $PadX * 2 + 2), $Height)
    Enable-DoubleBuffer $button
    $button.Add_MouseEnter({ param($s, $e) $s.Tag.Hover = $true; $s.Invalidate() })
    $button.Add_MouseLeave({ param($s, $e) $s.Tag.Hover = $false; $s.Tag.Down = $false; $s.Invalidate() })
    $button.Add_MouseDown({ param($s, $e) $s.Tag.Down = $true; $s.Invalidate() })
    $button.Add_MouseUp({ param($s, $e) $s.Tag.Down = $false; $s.Invalidate() })
    $button.Add_Paint({ param($s, $e) Invoke-PaintButton -Button $s -Graphics $e.Graphics })
    Set-ButtonState -Button $button -Enabled $true
    return $button
}

function Set-ButtonText {
    param($Button, [string]$Text)
    $Button.Text  = $Text
    $Button.Width = (Get-TextWidth $Text $Button.Font) + $Button.Tag.PadX * 2 + 2
}

function Set-ButtonState {
    param($Button, [bool]$Enabled)
    $Button.Enabled = $Enabled
    if ($Enabled) { $Button.Cursor = [System.Windows.Forms.Cursors]::Hand } else { $Button.Cursor = [System.Windows.Forms.Cursors]::Default }
    $Button.Invalidate()
}

function Invoke-PaintButton {
    param($Button, $Graphics)
    $st = $Button.Tag
    $Graphics.Clear((Get-Color $st.Surface))
    if (-not $Button.Enabled) {
        $fill = $CLR.BtnOffBg; $line = $CLR.BtnOffBd; $fore = $CLR.BtnOffFg
    }
    elseif ($st.Kind -eq 'primary') {
        $fill = $CLR.Accent
        if ($st.Down) { $fill = $CLR.AccentDown } elseif ($st.Hover) { $fill = $CLR.AccentHov }
        $line = $CLR.AccentLine; $fore = $CLR.AccentFg
    }
    else {
        $fill = $CLR.Btn
        if ($st.Down) { $fill = $CLR.BtnDown } elseif ($st.Hover) { $fill = $CLR.BtnHover }
        $line = $CLR.BtnBorder; $fore = $CLR.Text2
    }
    Invoke-FillRounded -Graphics $Graphics -X 0 -Y 0 -W $Button.Width -H $Button.Height -R 4 -Fill $fill -Border $line
    Invoke-DrawLine -Graphics $Graphics -Text $Button.Text -Font $Button.Font -Color $fore `
        -X ($Button.Width / 2) -Top 0 -LineHeight $Button.Height -Align 'Center'
}

# Собственный заголовок окна, как в макете: логотип, название и кнопки
# «свернуть» / «развернуть» (недоступна) / «закрыть». Окно таскается за заголовок.
function New-TitleBar {
    param($Form, [int]$Width = 760)
    $bar = New-Object System.Windows.Forms.Panel
    $bar.SetBounds(1, 1, $Width, 33)
    $bar.BackColor = Get-Color $CLR.TitleBar
    Enable-DoubleBuffer $bar
    $bar.Tag = @{ Form = $Form; Width = $Width; Hover = ''; Down = ''; Drag = $false; Grip = $null }

    $bar.Add_Paint({ param($s, $e) Invoke-PaintTitleBar -Bar $s -Graphics $e.Graphics })

    $bar.Add_MouseMove({
        param($s, $e)
        $t = $s.Tag
        if ($t.Drag) {
            $f = $t.Form
            $f.Location = New-Object System.Drawing.Point(($f.Left + $e.X - $t.Grip.X), ($f.Top + $e.Y - $t.Grip.Y))
            return
        }
        $hit = Get-TitleBarButton -Bar $s -X $e.X
        if ($hit -eq 'max') { $s.Cursor = [System.Windows.Forms.Cursors]::No } else { $s.Cursor = [System.Windows.Forms.Cursors]::Default }
        if ($hit -ne $t.Hover) { $t.Hover = $hit; $s.Invalidate() }
    })

    $bar.Add_MouseLeave({ param($s, $e) if ($s.Tag.Hover) { $s.Tag.Hover = ''; $s.Invalidate() } })

    $bar.Add_MouseDown({
        param($s, $e)
        if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $hit = Get-TitleBarButton -Bar $s -X $e.X
        if ($hit) { $s.Tag.Down = $hit } else { $s.Tag.Drag = $true; $s.Tag.Grip = $e.Location }
    })

    $bar.Add_MouseUp({
        param($s, $e)
        $t = $s.Tag
        $t.Drag = $false
        $hit = Get-TitleBarButton -Bar $s -X $e.X
        $inside = ($e.Y -ge 0 -and $e.Y -lt $s.Height)
        $pressed = $t.Down
        $t.Down = ''
        if (-not $inside -or $pressed -ne $hit) { return }
        if ($hit -eq 'close') { $t.Form.Close() }
        elseif ($hit -eq 'min') {
            $t.Hover = ''; $s.Invalidate()
            $t.Form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
        }
    })

    $Form.Controls.Add($bar)
    return $bar
}

function Get-TitleBarButton {
    param($Bar, [int]$X)
    $w = $Bar.Tag.Width
    if ($X -ge $w - 44)  { return 'close' }
    if ($X -ge $w - 88)  { return 'max' }
    if ($X -ge $w - 132) { return 'min' }
    return ''
}

function Invoke-PaintTitleBar {
    param($Bar, $Graphics)
    $g = $Graphics
    $w = $Bar.Tag.Width
    $hover = $Bar.Tag.Hover
    Invoke-FillRect -Graphics $g -Color $CLR.TitleLine -X 0 -Y 32 -W $w -H 1
    Invoke-DrawImage -Graphics $g -Image $App.UI.Images.Logo16 -X 10 -Y 8
    Invoke-DrawLine -Graphics $g -Text 'Russian Ranked Bedwars Service Restorer' -Font $App.UI.Fonts.TitleBar `
        -Color $CLR.TitleText -X 34 -Top 0 -LineHeight 32

    if ($hover -eq 'min')   { Invoke-FillRect -Graphics $g -Color $CLR.TitleHover -X ($w - 132) -Y 0 -W 44 -H 32 }
    if ($hover -eq 'close') { Invoke-FillRect -Graphics $g -Color $CLR.CloseHover -X ($w - 44) -Y 0 -W 44 -H 32 }

    # «свернуть» - полоска 10x1
    Invoke-FillRect -Graphics $g -Color $CLR.TitleText -X ($w - 132 + 17) -Y 16 -W 10 -H 1
    # «развернуть» - рамка 10x10, окно фиксированного размера, поэтому кнопка недоступна
    $pen = New-Object System.Drawing.Pen((Get-Color $CLR.MaxOff))
    try { $g.DrawRectangle($pen, ($w - 88 + 17), 11, 9, 9) } finally { $pen.Dispose() }
    # «закрыть» - крестик
    $color = $CLR.TitleText
    if ($hover -eq 'close') { $color = '#FFFFFF' }
    $x = $w - 44 + 17
    $pen = New-Object System.Drawing.Pen((Get-Color $color), 1.1)
    $oldMode = $g.SmoothingMode
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.DrawLine($pen, [single]($x + 0.5), [single]11.5, [single]($x + 9.5), [single]20.5)
        $g.DrawLine($pen, [single]($x + 9.5), [single]11.5, [single]($x + 0.5), [single]20.5)
    }
    finally { $g.SmoothingMode = $oldMode; $pen.Dispose() }
}

# Окно без системной рамки: тёмная рамка 1 пиксель, как в макете.
function New-ChromeForm {
    param([int]$Width = 760, [int]$Height = 620)
    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'RuRBW Service Restorer | rrbw.pro'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None
    $form.ClientSize      = New-Object System.Drawing.Size(($Width + 2), ($Height + 2))
    $form.BackColor       = Get-Color $CLR.WindowBd
    $form.Font            = $App.UI.Fonts.Base
    $form.KeyPreview      = $true
    # Значок на панели задач - тот же логотип. Одна иконка на весь сеанс,
    # Windows освободит её вместе с процессом.
    try { $form.Icon = [System.Drawing.Icon]::FromHandle($App.UI.Images.Logo36.GetHicon()) } catch { }
    return $form
}


# Затемнённый снимок окна-владельца - фон под модальной карточкой, как в макете.
function New-Backdrop {
    param($Owner)
    $w = $Owner.ClientSize.Width; $h = $Owner.ClientSize.Height
    $bitmap = New-Object System.Drawing.Bitmap($w, $h)
    $Owner.DrawToBitmap($bitmap, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)))
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        # rgba(10, 11, 12, .7)
        $shade = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(179, 10, 11, 12))
        try { $g.FillRectangle($shade, 0, 0, $w, $h) } finally { $shade.Dispose() }
    }
    finally { $g.Dispose() }
    return $bitmap
}

# Каркас модального окна: карточка 420 px с тенью поверх затемнённого окна.
# Текст рисует отдельная панель (его можно менять на ходу), кнопки добавляет вызывающий.
function New-ModalHost {
    param($Owner, [string]$Title, [string]$Text, [string]$Note, [int]$Width = 420)
    $fonts = $App.UI.Fonts
    $inner = $Width - 2 - 44
    $body = 20 + (Split-TextLines $Title $fonts.ModalTitle $inner).Count * 20.6 + 9 + (Split-TextLines $Text $fonts.ModalText $inner).Count * 20.8
    if ($Note) { $body += 7 + (Split-TextLines $Note $fonts.ModalNote $inner).Count * 18 }
    $body = [int][Math]::Ceiling($body + 18)
    $height = 2 + $body + 62

    if ($Owner) { $canvas = New-Backdrop -Owner $Owner }
    else { $canvas = New-Object System.Drawing.Bitmap($Width, $height) }
    $cx = [int](($canvas.Width - $Width) / 2)
    $cy = [int](($canvas.Height - $height) / 2)

    $g = [System.Drawing.Graphics]::FromImage($canvas)
    try {
        if ($Owner) {
            # тень 0 16px 40px rgba(0,0,0,.5), собранная из полупрозрачных слоёв
            for ($k = 14; $k -ge 1; $k--) {
                $spread = $k * 1.8
                $shadow = [System.Drawing.Color]::FromArgb(9, 0, 0, 0)
                Invoke-FillRounded -Graphics $g -X ($cx - $spread) -Y ($cy + 16 - $spread) -W ($Width + $spread * 2) -H ($height + $spread * 2) -R (6 + $spread) -Fill $shadow
            }
        }
        Invoke-FillRounded -Graphics $g -X $cx -Y $cy -W $Width -H $height -R 6 -Fill $CLR.Bg
        Invoke-FillRounded -Graphics $g -X $cx -Y $cy -W $Width -H (1 + $body) -R 6 -Fill $CLR.Panel -TopOnly
        Invoke-FillRect -Graphics $g -Color $CLR.Border2 -X ($cx + 1) -Y ($cy + 1 + $body) -W ($Width - 2) -H 1
        Invoke-FillRounded -Graphics $g -X $cx -Y $cy -W $Width -H $height -R 6 -Border $CLR.ModalBd
    }
    finally { $g.Dispose() }

    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar   = $false
    $form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None
    $form.BackColor       = Get-Color $CLR.WindowBd
    $form.ClientSize      = New-Object System.Drawing.Size($canvas.Width, $canvas.Height)
    $form.BackgroundImage = $canvas
    $form.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::None
    $form.Font            = $fonts.Base
    Enable-DoubleBuffer $form
    if ($Owner) {
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $form.Location = $Owner.PointToScreen([System.Drawing.Point]::Empty)
    }
    else { $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen }

    # Верх панели опущен на 5 px, чтобы не закрыть скруглённые углы карточки.
    $content = New-Object System.Windows.Forms.Panel
    $content.SetBounds(($cx + 1), ($cy + 6), ($Width - 2), ($body - 5))
    $content.BackColor = Get-Color $CLR.Panel
    Enable-DoubleBuffer $content
    $content.Tag = @{ Title = $Title; Text = $Text; Note = $Note }
    $content.Add_Paint({
        param($s, $e)
        $t = $s.Tag; $f = $App.UI.Fonts; $g = $e.Graphics
        $w = $s.Width - 44
        $y = 15
        $lines = Split-TextLines $t.Title $f.ModalTitle $w
        Invoke-DrawLines -Graphics $g -Lines $lines -Font $f.ModalTitle -Color $CLR.Text -X 22 -Top $y -LineHeight 20.6
        $y += $lines.Count * 20.6 + 9
        $lines = Split-TextLines $t.Text $f.ModalText $w
        Invoke-DrawLines -Graphics $g -Lines $lines -Font $f.ModalText -Color $CLR.ModalText -X 22 -Top $y -LineHeight 20.8
        $y += $lines.Count * 20.8
        if ($t.Note) {
            $lines = Split-TextLines $t.Note $f.ModalNote $w
            Invoke-DrawLines -Graphics $g -Lines $lines -Font $f.ModalNote -Color $CLR.Muted2 -X 22 -Top ($y + 7) -LineHeight 18
        }
    })
    $form.Controls.Add($content)

    return @{
        Form         = $form
        Canvas       = $canvas
        Content      = $content
        ButtonsRight = $cx + $Width - 1 - 22
        ButtonsTop   = $cy + 1 + $body + 1 + 13
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
        [int]$Width = 420
    )
    $fonts  = $App.UI.Fonts
    $result = @{ Value = 'secondary' }
    $modal  = New-ModalHost -Owner $Owner -Title $Title -Text $Text -Note $Note -Width $Width
    $dialog = $modal.Form
    $right  = $modal.ButtonsRight

    $btnPrimary = New-UiButton -Text $PrimaryText -Kind 'primary' -Font $fonts.ModalBtnMain -PadX 17
    $right -= $btnPrimary.Width
    $btnPrimary.Location = New-Object System.Drawing.Point($right, $modal.ButtonsTop)
    $btnPrimary.Add_Click({ $result.Value = 'primary'; $dialog.Close() }.GetNewClosure())
    $dialog.Controls.Add($btnPrimary)
    $dialog.AcceptButton = $btnPrimary
    $dialog.CancelButton = $btnPrimary

    if (-not [string]::IsNullOrWhiteSpace($SecondaryText)) {
        $btnSecondary = New-UiButton -Text $SecondaryText -Font $fonts.Button -PadX 15
        $right -= 8 + $btnSecondary.Width
        $btnSecondary.Location = New-Object System.Drawing.Point($right, $modal.ButtonsTop)
        $btnSecondary.Add_Click({ $result.Value = 'secondary'; $dialog.Close() }.GetNewClosure())
        $dialog.Controls.Add($btnSecondary)
        $dialog.CancelButton = $btnSecondary
    }

    $dialog.Add_Shown({ $btnPrimary.Focus() | Out-Null }.GetNewClosure())
    try {
        if ($Owner) { $dialog.ShowDialog($Owner) | Out-Null } else { $dialog.ShowDialog() | Out-Null }
    }
    finally { $dialog.Dispose(); $modal.Canvas.Dispose() }

    return $result.Value
}

# Обратный отсчёт после команды на перезагрузку. «Отменить» выполняет `shutdown /a`.
function Show-CountdownWindow {
    param($Owner, [int]$Seconds = 10)
    $fonts = $App.UI.Fonts
    $state = @{ Left = $Seconds; Cancelled = $false }
    $modal = New-ModalHost -Owner $Owner -Title 'Компьютер перезагрузится' `
        -Text "Перезагрузка через $Seconds сек. Сохраните всё важное." `
        -Note 'Отменить можно кнопкой ниже или командой shutdown /a.'
    $dialog  = $modal.Form
    $content = $modal.Content

    $btnCancel = New-UiButton -Text 'Отменить' -Font $fonts.Button -PadX 15
    $btnCancel.Location = New-Object System.Drawing.Point(($modal.ButtonsRight - $btnCancel.Width), $modal.ButtonsTop)
    $dialog.Controls.Add($btnCancel)
    $dialog.CancelButton = $btnCancel

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000

    $btnCancel.Add_Click({
        try { & shutdown.exe /a | Out-Null } catch { }
        $state.Cancelled = $true
        $timer.Stop()
        $dialog.Close()
    }.GetNewClosure())

    $timer.Add_Tick({
        $state.Left = $state.Left - 1
        if ($state.Left -le 0) {
            $timer.Stop()
            $content.Tag.Text = 'Перезагрузка...'
            $content.Invalidate()
            $dialog.Close()
        }
        else {
            $content.Tag.Text = "Перезагрузка через $($state.Left) сек. Сохраните всё важное."
            $content.Invalidate()
        }
    }.GetNewClosure())

    $dialog.Add_Shown({ $timer.Start() }.GetNewClosure())
    $dialog.Add_FormClosed({ $timer.Stop(); $timer.Dispose() }.GetNewClosure())

    try {
        if ($Owner) { $dialog.ShowDialog($Owner) | Out-Null } else { $dialog.ShowDialog() | Out-Null }
    }
    finally { $dialog.Dispose(); $modal.Canvas.Dispose() }

    return $state.Cancelled
}

# Экран «Нужны права администратора» из макета: показываем, когда игрок
# нажал «Нет» в окне контроля учётных записей.
function Show-NoAdminWindow {
    $fonts = $App.UI.Fonts
    $form = New-ChromeForm
    $null = New-TitleBar -Form $form

    $bodyText = 'Изменять службы Windows может только администратор. Нажмите кнопку ниже и подтвердите запрос Windows — программа перезапустится и продолжит проверку.'
    $bodyLines = Split-TextLines $bodyText $fonts.ModalText 430

    $button = New-UiButton -Text 'Перезапустить от имени администратора' -Kind 'primary' -Font $fonts.ButtonMain -PadX 20 -Height 39

    # Блок по центру: замок 30, заголовок, текст, кнопка, строка с кодом ошибки.
    $blockHeight = 30 + 16 + 25 + 9 + $bodyLines.Count * 20.8 + 22 + $button.Height + 13 + 16
    $top = [int]((587 - $blockHeight) / 2)

    $view = New-Object System.Windows.Forms.Panel
    $view.SetBounds(1, 34, 760, 587)
    $view.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $view
    $view.Tag = @{ Top = $top; Lines = $bodyLines; ButtonBottom = 0; Failed = $false }
    $form.Controls.Add($view)

    $buttonTop = [int]($top + 30 + 16 + 25 + 9 + $bodyLines.Count * 20.8 + 22)
    $button.Location = New-Object System.Drawing.Point([int](380 - $button.Width / 2), $buttonTop)
    $view.Tag.ButtonBottom = $buttonTop + $button.Height
    $view.Controls.Add($button)

    $view.Add_Paint({
        param($s, $e)
        $t = $s.Tag; $f = $App.UI.Fonts; $g = $e.Graphics
        $top = $t.Top

        # Замок из макета (viewBox 24, масштаб 1.25): корпус и дужка, обводка #E0797B.
        $ix = 380 - 15; $iy = $top
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Lock), 2.1)
        $oldMode = $g.SmoothingMode
        $path = New-RoundedPath -X ($ix + 5) -Y ($iy + 13.1) -W 20 -H 13.1 -R 1.9
        $shackle = New-Object System.Drawing.Drawing2D.GraphicsPath
        try {
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.DrawPath($pen, $path)
            $shackle.AddLine([single]($ix + 10), [single]($iy + 13.1), [single]($ix + 10), [single]($iy + 9.4))
            $shackle.AddArc([single]($ix + 10), [single]($iy + 4.4), [single]10, [single]10, [single]180, [single]180)
            $shackle.AddLine([single]($ix + 20), [single]($iy + 9.4), [single]($ix + 20), [single]($iy + 13.1))
            $g.DrawPath($pen, $shackle)
        }
        finally { $g.SmoothingMode = $oldMode; $pen.Dispose(); $path.Dispose(); $shackle.Dispose() }

        $y = $top + 30 + 16
        Invoke-DrawLine -Graphics $g -Text 'Нужны права администратора' -Font $f.NoAdminTitle -Color $CLR.Text -X 380 -Top $y -LineHeight 25 -Align 'Center'
        $y += 25 + 9
        Invoke-DrawLines -Graphics $g -Lines $t.Lines -Font $f.ModalText -Color $CLR.ModalText -X 380 -Top $y -LineHeight 20.8 -Align 'Center'

        $y = $t.ButtonBottom + 13
        if ($t.Failed) {
            $lines = Split-TextLines 'Windows не выдала права. Нажмите «Да» в окне контроля учётных записей — без этого включить службы невозможно.' $f.ModalNote 430
            Invoke-DrawLines -Graphics $g -Lines $lines -Font $f.ModalNote -Color $CLR.RedText -X 380 -Top $y -LineHeight 18 -Align 'Center'
        }
        else {
            Invoke-DrawLine -Graphics $g -Text 'Код: ERROR_ACCESS_DENIED (5)' -Font $f.Code -Color $CLR.Muted2 -X 380 -Top $y -LineHeight 16 -Align 'Center'
        }
    })

    $button.Add_Click({
        if (Invoke-Elevate) { $form.Close() }
        else { $view.Tag.Failed = $true; $view.Invalidate() }
    }.GetNewClosure())

    try { $form.ShowDialog() | Out-Null } finally { $form.Dispose() }
}


# --- Интерфейс: логика главного окна ---
function Set-StatusText {
    param([string]$Text)
    if ($App.UI.StatusLeft) { $App.UI.StatusLeft.Text = $Text }
    if ($App.UI.Status) { $App.UI.Status.Refresh() }
}

# «служба / службы / служб» по правилам русского языка.
function Get-ServiceWord {
    param([int]$Count)
    $tens = $Count % 100; $ones = $Count % 10
    if ($tens -ge 11 -and $tens -le 14) { return 'служб' }
    if ($ones -eq 1) { return 'служба' }
    if ($ones -ge 2 -and $ones -le 4) { return 'службы' }
    return 'служб'
}

# Карточка-сводка над таблицей и текст в строке состояния.
function Update-Summary {
    $fonts    = $App.UI.Fonts
    $total    = @($App.States).Count
    $problems = @($App.States | Where-Object { $_.IsProblem })
    $disabled = @($App.States | Where-Object { $_.ProblemKind -eq 'Startup' })
    $stopped  = @($App.States | Where-Object { $_.ProblemKind -eq 'Stopped' })
    $missing  = @($App.States | Where-Object { -not $_.Exists })
    $word     = Get-ServiceWord $total

    if ($problems.Count -eq 0) {
        $data = @{
            Color     = $CLR.Green
            Title     = "Все службы работают: $($total - $missing.Count) из $total"
            Text      = 'Журналы запуска программ ведутся. К проверке компьютера претензий не будет.'
            Breakdown = ''
        }
        Set-StatusText "Проверено $total $word, все работают"
    }
    else {
        $color = $CLR.Amber
        if ($disabled.Count -gt 0) { $color = $CLR.Red }
        $data = @{
            Color     = $color
            Title     = "Не работает служб: $($problems.Count) из $total"
            Text      = 'Пока эти службы выключены, на проверке за них вы получите бан, и с каждым разом длительность бана будет расти. Кнопка внизу включает их обратно'
            Breakdown = "С неправильным типом запуска: $($disabled.Count) — сами после перезагрузки не запустятся. Просто остановлено: $($stopped.Count)."
        }
        Set-StatusText "Проверено $total ${word}: отключено $($disabled.Count), остановлено $($stopped.Count)"
    }

    if ($missing.Count -gt 0) {
        $tail = "Нет в этой сборке Windows: $($missing.Count) — это не ошибка."
        if ($data.Breakdown) { $data.Breakdown = $data.Breakdown + ' ' + $tail } else { $data.Breakdown = $tail }
    }

    # Высота карточки идёт по содержимому, как в макете.
    $width = 728 - 2 - 30 - 18
    $data.TextLines  = Split-TextLines $data.Text $fonts.SummaryText $width
    $data.BreakLines = $null
    if ($data.Breakdown) { $data.BreakLines = Split-TextLines $data.Breakdown $fonts.SummaryHint $width }
    $height = 1 + 13 + 24 + 6 + $data.TextLines.Count * 18.75
    if ($data.BreakLines) { $height += 5 + $data.BreakLines.Count * 16.7 }
    $data.Height = [int][Math]::Ceiling($height + 13 + 1)

    $App.UI.SummaryData = $data
    Update-Layout
    $App.UI.Summary.Invalidate()
}

# Раскладка по вертикали: карточка сверху, под ней подпись раздела, таблица забирает остальное.
function Update-Layout {
    $ui = $App.UI
    if (-not $ui.GridHost) { return }
    $summaryHeight = 118
    if ($ui.SummaryData) { $summaryHeight = $ui.SummaryData.Height }
    $cardHeight = $summaryHeight
    if ($App.Running) { $cardHeight = 88 }

    $ui.Summary.SetBounds(16, 75, 728, $summaryHeight)
    $ui.Progress.SetBounds(16, 75, 728, 88)
    $sectionTop = 75 + $cardHeight
    $ui.Section.SetBounds(0, $sectionTop, 760, 36)

    $gridTop    = $sectionTop + 36
    $gridHeight = $ui.FooterTop - $gridTop
    $ui.GridHost.SetBounds(16, $gridTop, 728, $gridHeight)
    $ui.Grid.SetBounds(1, 1, 716, ($gridHeight - 2))
    $ui.Scroll.SetBounds(717, 30, 10, ($gridHeight - 31))
    $ui.GridHost.Invalidate()
    $ui.Scroll.Invalidate()
}

# Кнопки внизу прижаты вправо и подстраиваются под длину подписи.
function Update-FooterLayout {
    $ui = $App.UI
    $x = 744 - $ui.BtnFix.Width
    $ui.BtnFix.Location = New-Object System.Drawing.Point($x, 12)
    $x -= 8 + $ui.BtnReport.Width
    $ui.BtnReport.Location = New-Object System.Drawing.Point($x, 13)
    $x -= 8 + $ui.BtnRefresh.Width
    $ui.BtnRefresh.Location = New-Object System.Drawing.Point($x, 13)
}

function Set-SelectAll {
    param([bool]$Checked, [bool]$Available)
    $box = $App.UI.SelectAll
    $box.Tag.Checked   = $Checked
    $box.Tag.Available = $Available
    if ($Available -and -not $App.Running) { $box.Cursor = [System.Windows.Forms.Cursors]::Hand }
    else { $box.Cursor = [System.Windows.Forms.Cursors]::Default }
    $box.Invalidate()
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

    if ($fixable -eq 0) {
        $count = @($App.States).Count
        $App.UI.SectionHint = "$count $(Get-ServiceWord $count)"
    }
    else { $App.UI.SectionHint = "Выбрано $checked из $fixable" }
    $App.UI.Section.Invalidate()

    Set-SelectAll -Checked (($fixable -gt 0) -and ($checked -eq $fixable)) -Available ($fixable -gt 0)
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
    if ($grid.RowCount -gt 0) { try { $grid.FirstDisplayedScrollingRowIndex = 0 } catch { } }
    Update-Summary
    Update-Selection
    $App.UI.Scroll.Invalidate()
}

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
            $explanation = 'Перезагрузка уже запланирована другой программой. Утилита не отменяет чужие команды — дождитесь её или отмените сами.'
        }
        elseif ($code -eq -1) {
            $explanation = "Не удалось выполнить команду перезагрузки: $failure"
        }
        Show-DarkDialog -Owner $Owner -Title 'Не получилось перезагрузить' `
            -Text $explanation `
            -Note 'Перезагрузите компьютер вручную — без этого часть изменений не применится.' `
            -PrimaryText 'Понятно' | Out-Null
        return
    }

    $cancelled = Show-CountdownWindow -Owner $Owner -Seconds 10
    if ($cancelled) { Set-StatusText 'Перезагрузка отменена. Изменения применятся после следующей перезагрузки' }
    else { Set-StatusText 'Перезагрузка компьютера' }
}

# Крутилка в карточке прогресса. Во время работы со службой окно занято,
# поэтому она оживает между службами - на DoEvents.
function Set-Spinner {
    param([bool]$On)
    $timer = $App.UI.SpinTimer
    if (-not $timer) { return }
    if ($On) { $timer.Start() } else { $timer.Stop() }
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
    Update-Layout
    $grid.Enabled = $false
    Set-ButtonState -Button $App.UI.BtnFix     -Enabled $false
    Set-ButtonState -Button $App.UI.BtnRefresh -Enabled $false
    Set-ButtonState -Button $App.UI.BtnReport  -Enabled $false
    Set-SelectAll -Checked $App.UI.SelectAll.Tag.Checked -Available $App.UI.SelectAll.Tag.Available
    Set-ButtonText -Button $App.UI.BtnFix -Text 'Включение…'
    Update-FooterLayout
    Set-StatusText 'Включение служб'
    Set-Spinner -On $true

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
        Set-Spinner -On $false
        $App.Running = $false
        Set-ButtonText -Button $App.UI.BtnFix -Text 'Включить выбранные службы'
        Update-FooterLayout
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
                $App.Errors += "$($st.DisplayName) [$($st.Key)] — команда выполнена без ошибки, но состояние не изменилось. Проверьте, не возвращает ли настройку твикер из автозагрузки"
            }
        }
    }

    $errorText = ''
    if ($App.Errors.Count -gt 0) {
        $shown = @($App.Errors | Select-Object -First 3)
        $errorText = $shown -join "`r`n"
        if ($App.Errors.Count -gt 3) {
            $errorText += "`r`n… и ещё $($App.Errors.Count - 3). Полный список — в отчёте."
        }
    }

    if ($App.Fixed -gt 0) {
        Set-StatusText "Включено служб: $($App.Fixed). Требуется перезагрузка"
        $note = 'До перезагрузки службы считаются отключёнными.'
        if ($errorText) { $note = "Не удалось включить: $($App.Failed)." + "`r`n" + $errorText }

        $answer = Show-DarkDialog -Owner $App.UI.Form `
            -Title 'Службы включены' `
            -Text 'Изменения применятся после перезагрузки компьютера. Перезагрузить сейчас?' `
            -Note $note `
            -PrimaryText 'Перезагрузить' -SecondaryText 'Позже'

        if ($answer -eq 'primary') { Invoke-Reboot -Owner $App.UI.Form }
        else { Set-StatusText 'Перезагрузка отложена. Изменения применятся после неё' }
    }
    else {
        Set-StatusText "Не удалось включить службы. Ошибок: $($App.Failed)"
        Show-DarkDialog -Owner $App.UI.Form `
            -Title 'Не удалось включить службы' `
            -Text 'Windows отказала в изменении. Обычно это значит, что права администратора отозваны политикой или служба заблокирована сторонней программой.' `
            -Note $errorText -PrimaryText 'Понятно' | Out-Null
    }
}

# Сохранение отчёта на рабочий стол.
function Invoke-SaveReport {
    try {
        $path = Export-Report
        Set-StatusText "Отчёт сохранён: $path"
        Show-DarkDialog -Owner $App.UI.Form -Title 'Отчёт сохранён' `
            -Text 'Файл лежит на рабочем столе. Его можно показать проверяющему.' `
            -Note $path -PrimaryText 'Понятно' | Out-Null
    }
    catch {
        Show-DarkDialog -Owner $App.UI.Form -Title 'Не удалось сохранить отчёт' `
            -Text $_.Exception.Message -PrimaryText 'Понятно' | Out-Null
    }
}


# Положение ползунка самописной полосы прокрутки (штатная в тёмной теме светлая).
function Get-ScrollMetrics {
    $grid  = $App.UI.Grid
    $track = $App.UI.Scroll.Height
    $rows  = $grid.RowCount
    $visible = [Math]::Max(1, $grid.DisplayedRowCount($false))
    if ($rows -le $visible) { return @{ Track = $track; Size = 0; Top = 0; MaxFirst = 0; Visible = $visible } }
    $maxFirst = $rows - $visible
    $size  = [Math]::Max(24, [int]($track * $visible / $rows))
    $first = [Math]::Max(0, $grid.FirstDisplayedScrollingRowIndex)
    $top   = [int](($track - $size) * [Math]::Min($first, $maxFirst) / $maxFirst)
    return @{ Track = $track; Size = $size; Top = $top; MaxFirst = $maxFirst; Visible = $visible }
}

function Set-FirstRow {
    param([int]$Index)
    $grid = $App.UI.Grid
    if ($grid.RowCount -le 0) { return }
    $maxFirst = [Math]::Max(0, $grid.RowCount - [Math]::Max(1, $grid.DisplayedRowCount($false)))
    $Index = [Math]::Min($maxFirst, [Math]::Max(0, $Index))
    if ($grid.FirstDisplayedScrollingRowIndex -ne $Index) {
        try { $grid.FirstDisplayedScrollingRowIndex = $Index } catch { }
    }
    $App.UI.Scroll.Invalidate()
}

# --- Интерфейс: главное окно ---
function Show-MainWindow {
    $App.UI.Fonts  = New-AppFonts
    $App.UI.Images = New-AppImages
    $fonts = $App.UI.Fonts

    $form = New-ChromeForm
    $App.UI.Form = $form
    $null = New-TitleBar -Form $form

    $content = New-Object System.Windows.Forms.Panel
    $content.SetBounds(1, 34, 760, 587)
    $content.BackColor = Get-Color $CLR.Bg
    $form.Controls.Add($content)
    $App.UI.FooterTop = 502

    # --- шапка: логотип, название, Discord, бейдж администратора ---
    $header = New-Object System.Windows.Forms.Panel
    $header.SetBounds(0, 0, 760, 63)
    $header.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $header
    $header.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $f = $App.UI.Fonts
        Invoke-DrawImage -Graphics $g -Image $App.UI.Images.Logo36 -X 16 -Y 13
        Invoke-DrawLine -Graphics $g -Text 'Russian Ranked Bedwars Service Restorer' -Font $f.Header -Color $CLR.Text -X 63 -Top 11 -LineHeight 20.6

        $badgeText = 'Администратор'
        $badgeWidth = 1 + 8 + 6 + 6 + (Get-TextWidth $badgeText $f.Badge) + 8 + 1
        $bx = 744 - $badgeWidth; $by = 9
        Invoke-FillRounded -Graphics $g -X $bx -Y $by -W $badgeWidth -H 23 -R 3 -Fill $CLR.BadgeBg -Border $CLR.BadgeBd
        Invoke-DrawDot -Graphics $g -Color $CLR.Green -X ($bx + 9) -Y ($by + 8.5) -Size 6
        Invoke-DrawLine -Graphics $g -Text $badgeText -Font $f.Badge -Color $CLR.GreenText -X ($bx + 21) -Top $by -LineHeight 23
        Invoke-DrawLine -Graphics $g -Text 'by @slurov' -Font $f.Author -Color $CLR.Muted2 -X 744 -Top 39 -LineHeight 15 -Align 'Right'

        Invoke-FillRect -Graphics $g -Color $CLR.Border2 -X 0 -Y 62 -W 760 -H 1
    })
    $content.Controls.Add($header)

    # Ссылка на Discord со значком. Открывается только по явному нажатию и через
    # explorer.exe, чтобы браузер НЕ унаследовал права администратора этого процесса.
    $link = New-Object System.Windows.Forms.Panel
    $link.SetBounds(63, 35, (13 + 6 + (Get-TextWidth 'discord.gg/rurbw' $fonts.Link) + 2), 16)
    $link.BackColor = Get-Color $CLR.Bg
    $link.Cursor = [System.Windows.Forms.Cursors]::Hand
    Enable-DoubleBuffer $link
    $link.Tag = @{ Hover = $false }
    $link.Add_Paint({
        param($s, $e)
        $color = $CLR.Muted
        if ($s.Tag.Hover) { $color = $CLR.Text2 }
        Invoke-DrawTinted -Graphics $e.Graphics -Image $App.UI.Images.Discord -X 0 -Y 2 -Color $color
        Invoke-DrawLine -Graphics $e.Graphics -Text 'discord.gg/rurbw' -Font $App.UI.Fonts.Link -Color $color -X 19 -Top 0 -LineHeight 16
    })
    $link.Add_MouseEnter({ param($s, $e) $s.Tag.Hover = $true; $s.Invalidate() })
    $link.Add_MouseLeave({ param($s, $e) $s.Tag.Hover = $false; $s.Invalidate() })
    $link.Add_Click({
        try { Start-Process -FilePath 'explorer.exe' -ArgumentList $DISCORD_URL }
        catch { }
    })
    $header.Controls.Add($link)

    # --- карточка «сводка» ---
    $summary = New-Object System.Windows.Forms.Panel
    $summary.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $summary
    $summary.Add_Paint({
        param($s, $e)
        $d = $App.UI.SummaryData
        if (-not $d) { return }
        $g = $e.Graphics; $f = $App.UI.Fonts
        Invoke-FillRounded -Graphics $g -X 0 -Y 0 -W $s.Width -H $s.Height -R 5 -Fill $CLR.Panel -Border $CLR.Border
        Invoke-DrawDot -Graphics $g -Color $d.Color -X 16 -Y 21.5 -Size 9
        Invoke-DrawLine -Graphics $g -Text $d.Title -Font $f.SummaryTitle -Color $CLR.Text -X 34 -Top 14 -LineHeight 24
        Invoke-DrawLines -Graphics $g -Lines $d.TextLines -Font $f.SummaryText -Color $CLR.ModalText -X 34 -Top 44 -LineHeight 18.75
        if ($d.BreakLines) {
            $y = 44 + $d.TextLines.Count * 18.75 + 5
            Invoke-DrawLines -Graphics $g -Lines $d.BreakLines -Font $f.SummaryHint -Color $CLR.Muted3 -X 34 -Top $y -LineHeight 16.7
        }
    })
    $content.Controls.Add($summary)
    $App.UI.Summary = $summary

    # --- карточка «идёт включение» ---
    $progress = New-Object System.Windows.Forms.Panel
    $progress.BackColor = Get-Color $CLR.Bg
    $progress.Visible = $false
    Enable-DoubleBuffer $progress
    $progress.Add_Paint({
        param($s, $e)
        $g = $e.Graphics; $f = $App.UI.Fonts; $p = $App.Progress
        Invoke-FillRounded -Graphics $g -X 0 -Y 0 -W $s.Width -H $s.Height -R 5 -Fill $CLR.Panel -Border $CLR.Border

        # крутилка: дуга в 3/4 окружности, как в макете
        $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Spinner), 1.5)
        $oldMode = $g.SmoothingMode
        try {
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.DrawArc($pen, [single]17.6, [single]18.6, [single]9.75, [single]9.75, [single]$App.UI.SpinAngle, [single]270)
        }
        finally { $g.SmoothingMode = $oldMode; $pen.Dispose() }

        Invoke-DrawLine -Graphics $g -Text 'Включение служб' -Font $f.ProgressTop -Color $CLR.Text -X 38 -Top 14 -LineHeight 19
        Invoke-DrawLine -Graphics $g -Text "$($p.Index) / $($p.Total)" -Font $f.Counter -Color $CLR.Muted -X 712 -Top 14 -LineHeight 19 -Align 'Right'
        Invoke-FillRounded -Graphics $g -X 16 -Y 45 -W 696 -H 4 -R 2 -Fill $CLR.Chrome
        if ($p.Total -gt 0 -and $p.Index -gt 0) {
            $done = [Math]::Max(4, 696 * $p.Index / $p.Total)
            Invoke-FillRounded -Graphics $g -X 16 -Y 45 -W $done -H 4 -R 2 -Fill $CLR.Accent
        }
        Invoke-DrawLine -Graphics $g -Text $p.Line -Font $f.MonoLine -Color $CLR.ModalText -X 16 -Top 58 -LineHeight 16 -MaxWidth 696
    })
    $content.Controls.Add($progress)
    $App.UI.Progress = $progress

    $spin = New-Object System.Windows.Forms.Timer
    $spin.Interval = 50
    $spin.Add_Tick({
        $App.UI.SpinAngle = ($App.UI.SpinAngle + 24) % 360
        $App.UI.Progress.Invalidate((New-Object System.Drawing.Rectangle(14, 16, 18, 18)))
    })
    $App.UI.SpinTimer = $spin
    $App.UI.SpinAngle = 0

    # --- подпись раздела ---
    $section = New-Object System.Windows.Forms.Panel
    $section.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $section
    $section.Add_Paint({
        param($s, $e)
        $f = $App.UI.Fonts
        Invoke-DrawSpaced -Graphics $e.Graphics -Text 'СЛУЖБЫ WINDOWS' -Font $f.Section -Color $CLR.Muted2 -X 18 -Top 14 -LineHeight 15 -Spacing 1
        Invoke-DrawLine -Graphics $e.Graphics -Text $App.UI.SectionHint -Font $f.Hint -Color $CLR.Muted2 -X 742 -Top 14 -LineHeight 15 -Align 'Right'
    })
    $content.Controls.Add($section)
    $App.UI.Section = $section
    $App.UI.SectionHint = ''

    # --- таблица ---
    $gridHost = New-Object System.Windows.Forms.Panel
    $gridHost.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $gridHost
    $gridHost.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        Invoke-FillRounded -Graphics $g -X 0 -Y 0 -W $s.Width -H $s.Height -R 5 -Fill $CLR.Panel -TopOnly
        # Кусок шапки над полосой прокрутки - в макете шапка идёт на всю ширину.
        $path = New-RoundedPath -X 0.5 -Y 0.5 -W ($s.Width - 1) -H ($s.Height - 1) -R 5 -TopOnly
        $saved = $g.Save()
        try {
            $g.SetClip($path)
            Invoke-FillRect -Graphics $g -Color $CLR.PanelHead -X 717 -Y 1 -W 10 -H 28
            Invoke-FillRect -Graphics $g -Color $CLR.Border -X 717 -Y 29 -W 10 -H 1
        }
        finally { $g.Restore($saved); $path.Dispose() }
        Invoke-FillRounded -Graphics $g -X 0 -Y 0 -W $s.Width -H $s.Height -R 5 -Border $CLR.Border -TopOnly
    })
    $content.Controls.Add($gridHost)
    $App.UI.GridHost = $gridHost

    $grid = New-Object System.Windows.Forms.DataGridView
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
    # Штатная полоса прокрутки в тёмной теме светлая - рисуем свою (см. ниже).
    $grid.ScrollBars                 = [System.Windows.Forms.ScrollBars]::None
    $grid.ShowCellToolTips           = $false
    $grid.TabStop                    = $true

    # Тёмная тема в DataGridView не наследуется - задаём цвета явно.
    $grid.DefaultCellStyle.BackColor          = Get-Color $CLR.Panel
    $grid.DefaultCellStyle.ForeColor          = Get-Color $CLR.Text2
    $grid.DefaultCellStyle.SelectionBackColor = Get-Color $CLR.Panel
    $grid.DefaultCellStyle.SelectionForeColor = Get-Color $CLR.Text2
    $grid.DefaultCellStyle.Font               = $fonts.RowText
    $grid.RowsDefaultCellStyle.BackColor      = Get-Color $CLR.Panel
    $grid.ColumnHeadersDefaultCellStyle.BackColor          = Get-Color $CLR.PanelHead
    $grid.ColumnHeadersDefaultCellStyle.ForeColor          = Get-Color $CLR.Head
    $grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = Get-Color $CLR.PanelHead
    $grid.ColumnHeadersDefaultCellStyle.SelectionForeColor = Get-Color $CLR.Head
    $grid.ColumnHeadersDefaultCellStyle.Font               = $fonts.GridHead
    Enable-DoubleBuffer $grid

    # Сетка колонок из макета: 4px отступ | 34 | 1.3fr | 96 | 112 | 1.7fr | 4px
    $columns = @(
        @{ Type = 'Check'; Name = 'Select';      Header = '';            Width = 38 }
        @{ Type = 'Text';  Name = 'Service';     Header = 'Служба';      Width = 202 }
        @{ Type = 'Text';  Name = 'State';       Header = 'Состояние';   Width = 96 }
        @{ Type = 'Text';  Name = 'Startup';     Header = 'Тип запуска'; Width = 112 }
        @{ Type = 'Text';  Name = 'Description'; Header = 'Что делает';  Width = 0 }
    )
    foreach ($c in $columns) {
        if ($c.Type -eq 'Check') { $col = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn }
        else { $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn; $col.ReadOnly = $true }
        $col.Name       = $c.Name
        $col.HeaderText = $c.Header
        $col.SortMode   = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
        $col.Resizable  = [System.Windows.Forms.DataGridViewTriState]::False
        if ($c.Width -gt 0) { $col.Width = $c.Width }
        else { $col.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill }
        $grid.Columns.Add($col) | Out-Null
    }
    $gridHost.Controls.Add($grid)
    $App.UI.Grid = $grid

    # Строки рисуем сами: подсветка, двухстрочное имя службы, цветные индикаторы.
    $grid.Add_CellPainting({
        param($s, $e)
        if ($e.ColumnIndex -lt 0) { return }
        $g = $e.Graphics; $f = $App.UI.Fonts; $b = $e.CellBounds

        # --- шапка таблицы ---
        if ($e.RowIndex -lt 0) {
            Invoke-FillRect -Graphics $g -Color $CLR.PanelHead -X $b.X -Y $b.Y -W $b.Width -H $b.Height
            Invoke-FillRect -Graphics $g -Color $CLR.Border -X $b.X -Y ($b.Bottom - 1) -W $b.Width -H 1
            if ($e.ColumnIndex -eq 0) {
                # Скруглённый левый верхний угол рамки таблицы попадает на эту ячейку.
                $corner = New-RoundedPath -X -0.5 -Y -0.5 -W 727 -H 200 -R 5 -TopOnly
                $area = New-Object System.Drawing.Region((New-Object System.Drawing.Rectangle(0, 0, 6, 6)))
                $brush = New-Object System.Drawing.SolidBrush((Get-Color $CLR.Bg))
                $pen = New-Object System.Drawing.Pen((Get-Color $CLR.Border))
                $saved = $g.Save()
                try {
                    $area.Exclude($corner)
                    $g.FillRegion($brush, $area)
                    $g.SetClip((New-Object System.Drawing.Rectangle(0, 0, 6, 6)))
                    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $g.DrawPath($pen, $corner)
                }
                finally { $g.Restore($saved); $corner.Dispose(); $area.Dispose(); $brush.Dispose(); $pen.Dispose() }
            }
            $headerText = [string]$e.FormattedValue
            if ($headerText) {
                Invoke-DrawLine -Graphics $g -Text $headerText.ToUpper() -Font $f.GridHead -Color $CLR.Head -X $b.X -Top $b.Y -LineHeight ($b.Height - 1) -MaxWidth ($b.Width - 4)
            }
            $e.Handled = $true
            return
        }

        $row   = $s.Rows[$e.RowIndex]
        $state = $row.Tag
        if (-not $state) { return }

        # Подсветка строки: красная - неправильный тип запуска, жёлтая - служба
        # остановлена, серая - службы нет в системе, обычная - всё в порядке.
        $back = $CLR.Panel; $mark = ''
        if (-not $state.Exists) { $back = $CLR.RowMissing }
        elseif ($state.ProblemKind -eq 'Startup') { $back = $CLR.RowProblem; $mark = $CLR.Red }
        elseif ($state.ProblemKind -eq 'Stopped') { $back = $CLR.RowWarn;    $mark = $CLR.Amber }
        Invoke-FillRect -Graphics $g -Color $back -X $b.X -Y $b.Y -W $b.Width -H $b.Height
        Invoke-FillRect -Graphics $g -Color $CLR.Line -X $b.X -Y ($b.Bottom - 1) -W $b.Width -H 1

        switch ($e.ColumnIndex) {
            0 {
                if ($mark) { Invoke-FillRect -Graphics $g -Color $mark -X $b.X -Y $b.Y -W 2 -H ($b.Height - 1) }
                $isChecked = $false
                try { $isChecked = [bool]$row.Cells[0].Value } catch { }
                Invoke-DrawCheckBox -Graphics $g -X ($b.X + 13) -Y ($b.Y + 14) -Checked $isChecked -Enabled (-not $row.Cells[0].ReadOnly)
            }
            1 {
                $titleColor = '#A8ADB4'
                if ($state.IsProblem) { $titleColor = $CLR.Text } elseif (-not $state.Exists) { $titleColor = $CLR.Muted2 }
                Invoke-DrawLine -Graphics $g -Text $state.DisplayName -Font $f.RowTitle -Color $titleColor -X $b.X -Top ($b.Y + 5) -LineHeight 17 -MaxWidth ($b.Width - 8)
                Invoke-DrawLine -Graphics $g -Text $state.Key -Font $f.RowId -Color $CLR.Muted2 -X $b.X -Top ($b.Y + 22) -LineHeight 15 -MaxWidth ($b.Width - 8)
            }
            2 {
                $dot = $CLR.Green; $color = $CLR.Muted; $text = 'Не найдена'
                if (-not $state.Exists) { $dot = $CLR.Muted2; $color = $CLR.Muted2 }
                else {
                    $text = Get-StatusRu $state.CurrentStatus
                    if ($state.ProblemKind -eq 'Startup') { $dot = $CLR.Red; $color = $CLR.RedText }
                    elseif ($state.ProblemKind -eq 'Stopped') { $dot = $CLR.Amber; $color = $CLR.AmberText }
                }
                Invoke-DrawDot -Graphics $g -Color $dot -X $b.X -Y ($b.Y + 18.5) -Size 6
                Invoke-DrawLine -Graphics $g -Text $text -Font $f.RowText -Color $color -X ($b.X + 13) -Top $b.Y -LineHeight ($b.Height - 1) -MaxWidth ($b.Width - 13)
            }
            3 {
                $text = '—'; $color = $CLR.Muted3
                if ($state.Exists) {
                    $text = Get-StartupRu $state.CurrentStartup
                    if ($state.ProblemKind -eq 'Startup') { $color = $CLR.RedText } elseif ($state.IsProblem) { $color = $CLR.Muted }
                }
                Invoke-DrawLine -Graphics $g -Text $text -Font $f.RowText -Color $color -X $b.X -Top $b.Y -LineHeight ($b.Height - 1) -MaxWidth ($b.Width - 8)
            }
            default {
                $color = $CLR.Muted3
                if ($state.IsProblem) { $color = $CLR.Text3 }
                # У строк, которые утилита не чинит, вместо описания - что делать игроку.
                $text = $state.Description
                if ($state.Hint) { $text = $state.Hint; $color = $CLR.AmberText }
                $lines = Split-TextLines $text $f.RowText ($b.Width - 10)
                $top = $b.Y + (($b.Height - 1) - $lines.Count * 16.2) / 2
                Invoke-DrawLines -Graphics $g -Lines $lines -Font $f.RowText -Color $color -X $b.X -Top $top -LineHeight 16.2
            }
        }
        $e.Handled = $true
    })

    # Галочка должна применяться сразу, а не после ухода фокуса.
    $grid.Add_CurrentCellDirtyStateChanged({
        param($s, $e)
        if ($s.IsCurrentCellDirty) { $s.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
    })

    $grid.Add_CellValueChanged({
        param($s, $e)
        if ($App.Populating -or $e.RowIndex -lt 0) { return }
        $s.InvalidateRow($e.RowIndex)
        Update-Selection
    })

    # Клик по любому месту строки тоже переключает галочку - так удобнее.
    $grid.Add_CellClick({
        param($s, $e)
        if ($App.Running) { return }
        if ($e.RowIndex -lt 0 -or $e.ColumnIndex -le 0) { return }
        $cell = $s.Rows[$e.RowIndex].Cells[0]
        if ($cell.ReadOnly) { return }
        $cell.Value = (-not [bool]$cell.Value)
    })

    # Рука над строками, которые можно выбрать, как cursor: pointer в макете.
    $grid.Add_CellMouseMove({
        param($s, $e)
        $cursor = [System.Windows.Forms.Cursors]::Default
        if (-not $App.Running -and $e.RowIndex -ge 0) {
            $st = $s.Rows[$e.RowIndex].Tag
            if ($st -and $st.CanFix) { $cursor = [System.Windows.Forms.Cursors]::Hand }
        }
        if ($s.Cursor -ne $cursor) { $s.Cursor = $cursor }
    })

    $grid.Add_MouseWheel({
        param($s, $e)
        if ($e -is [System.Windows.Forms.HandledMouseEventArgs]) { $e.Handled = $true }
        $step = 2
        if ($e.Delta -gt 0) { $step = -2 }
        Set-FirstRow ($s.FirstDisplayedScrollingRowIndex + $step)
    })
    $grid.Add_Scroll({ $App.UI.Scroll.Invalidate() })

    # --- своя полоса прокрутки: дорожка #2B2D31, ползунок #1E1F22, как в макете ---
    $scroll = New-Object System.Windows.Forms.Panel
    $scroll.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $scroll
    $scroll.Tag = @{ Drag = $false; StartY = 0; StartFirst = 0 }
    $scroll.Add_Paint({
        param($s, $e)
        $m = Get-ScrollMetrics
        if ($m.Size -gt 0) {
            Invoke-FillRounded -Graphics $e.Graphics -X 2 -Y ($m.Top + 2) -W 6 -H ($m.Size - 4) -R 3 -Fill $CLR.Thumb
        }
    })
    $scroll.Add_MouseDown({
        param($s, $e)
        $m = Get-ScrollMetrics
        if ($m.Size -eq 0) { return }
        $first = $App.UI.Grid.FirstDisplayedScrollingRowIndex
        if ($e.Y -ge $m.Top -and $e.Y -lt ($m.Top + $m.Size)) {
            $s.Tag.Drag = $true; $s.Tag.StartY = $e.Y; $s.Tag.StartFirst = $first
        }
        elseif ($e.Y -lt $m.Top) { Set-FirstRow ($first - $m.Visible) }
        else { Set-FirstRow ($first + $m.Visible) }
    })
    $scroll.Add_MouseMove({
        param($s, $e)
        if (-not $s.Tag.Drag) { return }
        $m = Get-ScrollMetrics
        if ($m.Size -eq 0 -or $m.Track -le $m.Size) { return }
        $rowsPerPixel = $m.MaxFirst / ($m.Track - $m.Size)
        Set-FirstRow ([int][Math]::Round($s.Tag.StartFirst + ($e.Y - $s.Tag.StartY) * $rowsPerPixel))
    })
    $scroll.Add_MouseUp({ param($s, $e) $s.Tag.Drag = $false })
    $gridHost.Controls.Add($scroll)
    $App.UI.Scroll = $scroll

    # --- нижняя панель ---
    $footer = New-Object System.Windows.Forms.Panel
    $footer.SetBounds(0, $App.UI.FooterTop, 760, 60)
    $footer.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $footer
    $footer.Add_Paint({ param($s, $e) Invoke-FillRect -Graphics $e.Graphics -Color $CLR.Border2 -X 0 -Y 0 -W $s.Width -H 1 })
    $content.Controls.Add($footer)

    # «Выбрать все» в стиле макета. Не ставит галочки на недоступных строках.
    $selectAll = New-Object System.Windows.Forms.Panel
    $selectAll.SetBounds(16, 20, (15 + 8 + (Get-TextWidth 'Выбрать все' $fonts.SelectAll) + 2), 20)
    $selectAll.BackColor = Get-Color $CLR.Bg
    Enable-DoubleBuffer $selectAll
    $selectAll.Tag = @{ Checked = $false; Available = $false }
    $selectAll.Add_Paint({
        param($s, $e)
        $t = $s.Tag
        $opacity = 1
        if (-not $t.Available) { $opacity = 0.45 }
        Invoke-DrawCheckBox -Graphics $e.Graphics -X 0 -Y 2.5 -Checked $t.Checked -Enabled $t.Available -Opacity $opacity -Surface $CLR.Bg
        $color = $CLR.Text3
        if ($opacity -lt 1) { $color = Get-Blend $CLR.Text3 $CLR.Bg $opacity }
        Invoke-DrawLine -Graphics $e.Graphics -Text 'Выбрать все' -Font $App.UI.Fonts.SelectAll -Color $color -X 23 -Top 0 -LineHeight 20
    })
    $selectAll.Add_Click({
        param($s, $e)
        if ($App.Running -or -not $s.Tag.Available) { return }
        $target = -not $s.Tag.Checked
        $App.Populating = $true
        try {
            foreach ($row in $App.UI.Grid.Rows) {
                $st = $row.Tag
                if ($st -and $st.CanFix) { $row.Cells[0].Value = $target }
            }
        }
        finally { $App.Populating = $false }
        $App.UI.Grid.Invalidate()
        Update-Selection
    })
    $footer.Controls.Add($selectAll)
    $App.UI.SelectAll = $selectAll

    $btnRefresh = New-UiButton -Text 'Обновить' -Font $fonts.Button
    $btnRefresh.Add_Click({ Invoke-Scan })
    $footer.Controls.Add($btnRefresh)
    $App.UI.BtnRefresh = $btnRefresh

    $btnReport = New-UiButton -Text 'Сохранить отчёт' -Font $fonts.Button
    $btnReport.Add_Click({ Invoke-SaveReport })
    $footer.Controls.Add($btnReport)
    $App.UI.BtnReport = $btnReport

    $btnFix = New-UiButton -Text 'Включить выбранные службы' -Kind 'primary' -Font $fonts.ButtonMain -PadX 17 -Height 37
    $btnFix.Add_Click({ Invoke-FixSelected })
    $footer.Controls.Add($btnFix)
    $App.UI.BtnFix = $btnFix
    Update-FooterLayout

    # --- строка состояния ---
    $statusLine = New-Object System.Windows.Forms.Panel
    $statusLine.SetBounds(0, 562, 760, 1)
    $statusLine.BackColor = Get-Color $CLR.TitleLine
    $content.Controls.Add($statusLine)

    $status = New-Object System.Windows.Forms.StatusStrip
    $status.Dock       = [System.Windows.Forms.DockStyle]::Bottom
    $status.AutoSize   = $false
    $status.Height     = 24
    $status.SizingGrip = $false
    $status.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::System
    $status.BackColor  = Get-Color $CLR.Chrome
    $status.Padding    = New-Object System.Windows.Forms.Padding(12, 0, 12, 0)

    # StatusStrip плохо поддаётся перекраске: штатный отрисовщик рисует свой фон
    # поверх BackColor. Поэтому красим и сами надписи - левая растянута на всю ширину.
    $statusLeft = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLeft.Spring    = $true
    $statusLeft.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $statusLeft.ForeColor = Get-Color $CLR.Muted
    $statusLeft.BackColor = Get-Color $CLR.Chrome
    $statusLeft.Font      = $fonts.Status
    $statusLeft.Text      = 'Запуск...'

    $statusRight = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusRight.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $statusRight.ForeColor = Get-Color $CLR.StatusRight
    $statusRight.BackColor = Get-Color $CLR.Chrome
    $statusRight.Font      = $fonts.Status
    $statusRight.Text      = "Администратор   $SCRIPT_VERSION"

    $status.Items.AddRange([System.Windows.Forms.ToolStripItem[]]@($statusLeft, $statusRight))
    $content.Controls.Add($status)
    $App.UI.Status     = $status
    $App.UI.StatusLeft = $statusLeft

    Update-Layout

    # Пока идёт включение служб, окно закрывать нельзя: DoEvents пропускает клики
    # внутрь цикла, и закрытие на середине уронило бы процесс на уже
    # уничтоженных элементах управления, оставив службы наполовину починенными.
    $form.Add_FormClosing({
        param($s, $e)
        if ($App.Running) {
            $e.Cancel = $true
            Set-StatusText 'Идёт включение служб — дождитесь окончания'
        }
    })

    $form.Add_Shown({ Invoke-Scan })

    try {
        $form.ShowDialog() | Out-Null
    }
    finally {
        $spin.Stop(); $spin.Dispose()
        $form.Dispose()
        Remove-AppResources
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
        $App.UI.Fonts  = New-AppFonts
        $App.UI.Images = New-AppImages
        try { Show-NoAdminWindow } finally { Remove-AppResources }
    }
    # Копия уже работает от администратора - этот процесс больше не нужен.
    exit
}
