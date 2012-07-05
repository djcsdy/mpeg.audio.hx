package mpeg.audio;

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;

class InputMock extends Input {
    var bytesQueue:Iterator<Int>;

    public var onReadByte:Void -> Int;

    public function new() {
        bytesQueue = null;
        onReadByte = null;
    }

    override public function readByte() {
        if (onReadByte != null) {
            return onReadByte();
        } else if (bytesQueue != null && bytesQueue.hasNext()) {
            return bytesQueue.next();
        } else {
            throw new Eof();
        }
    }

    public function enqueueBytes(bytes:Bytes) {
        enqueueIterable({
            iterator: function() {
                var pos = 0;
                return {
                    hasNext: function() {
                        return pos < bytes.length;
                    },
                    next: function() {
                        return bytes.get(pos++);
                    }
                };
            }
        });
    }

    public function enqueueIterable(bytes:Iterable<Int>) {
        if (bytesQueue == null) {
            bytesQueue = bytes.iterator();
        } else {
            var previousQueue = bytesQueue;
            var nextQueue = bytes.iterator();

            bytesQueue = {
                hasNext: function() {
                    return previousQueue.hasNext() || nextQueue.hasNext();
                },
                next: function() {
                    if (previousQueue.hasNext()) {
                        return previousQueue.next();
                    } else {
                        return nextQueue.next();
                    }
                }
            };
        }

        onReadByte = null;
    }
}
