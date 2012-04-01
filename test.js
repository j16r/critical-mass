console.log('Loading a web page');
var page = new WebPage();
var url = "http://www.phantomjs.org/";
page.open(url, function (status) {
    //Page is loaded!
    phantom.exit();
});
