function Obj(y) {
    this.x = y;
    this.doIt = function(x) { this.x = x; return this; };
}
var o = new Obj(2);
o.doIt(2).doIt('a');