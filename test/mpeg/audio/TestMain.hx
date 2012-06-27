package mpeg.audio;

import haxe.unit.TestRunner;

class TestMain {
    static function main () {
        #if flash
        var oldPrint = TestRunner.print;
        TestRunner.print = function (value) {
            oldPrint(value);
            flash.Lib.trace(value);
        }
        #end

        var testRunner = new TestRunner();
        testRunner.add(new MpegAudioReaderTest());
        testRunner.run();
    }
}
