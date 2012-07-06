package mpeg.audio;

import haxe.io.Bytes;

enum Element {
    Frame(frame:Frame);
    Info(info:Info);
    Unknown(bytes:Bytes);
    End;
}