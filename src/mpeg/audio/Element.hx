package mpeg.audio;

import haxe.io.Bytes;

enum Element {
    Frame (frame:Frame);
    Unknown (bytes:Bytes);
    End;
}