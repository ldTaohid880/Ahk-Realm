#Requires AutoHotkey v2.0

class MyClass {
    __New(name) {
        this.name := name
    }

    sayHello(){
        MsgBox("Hello " this.name)
    }
}