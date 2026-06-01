#Requires AutoHotkey v2.0

count := 2 + 3

^!l::
{
    Loop count
    {
        if A_Index <= 3
        {
            MsgBox "Loop item " . A_Index
        }
    }
}

^!c::
{
    if count >= 5 && count != 0
    {
        MsgBox "Expressions and conditions work"
    }
}
