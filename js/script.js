//greeting
var hrs = new Date().getHours();
var greet;

if (hrs < 4) {
    greet = 'おやすみ…';
} else if (hrs < 12) {
    greet = 'おはよう！';
} else if (hrs < 17) {
    greet = 'こんにちは！';
} else {
    greet = 'こんばんは！';
}

document.getElementById('lblGreetings').innerHTML = '<b>' + greet + '</b>';
