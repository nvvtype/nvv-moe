//greeting
var myDate = new Date();
var hrs = myDate.getHours();

var greet;
var subGreet;

if (hrs < 12){
    greet = 'おはよう！';}
else if (hrs >= 12 && hrs <= 17){
    greet = 'こんにちは！';}
else if (hrs >= 17 && hrs <= 24){
    greet = 'こんばんは！';}


document.getElementById('lblGreetings').innerHTML =
    '<b>' + greet + '</b>';
