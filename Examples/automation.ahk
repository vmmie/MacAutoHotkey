#Requires AutoHotkey v2.0

name := "macOS"

^!h::
{
    MsgBox name
}

^!s::Send "Typed by macahk"

^!m::
{
    MouseMove 400, 400
    Click
}

::brb::be right back
