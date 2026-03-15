# mkdoc

Source code documentation tool using embedded Markdown for programming
languages supporting either multiline comments or at least the # character for comments.


* Download current code and manuals:  [mkdoc.zip](https://downgit.github.io/#/home?url=https://github.com/mittelmark/mkdoc/tree/main/mkdoc)
* Short Manual generated from doctools manpage [mkdoc.html](http://htmlpreview.github.io/?https://github.com/mittelmark/mkdoc/blob/master/mkdoc/mkdoc.html)
* Long Manual generated from mkdoc.tcl directly [mkdoc-mkdoc.html](http://htmlpreview.github.io/?https://github.com/mittelmark/mkdoc/blob/master/mkdoc/mkdoc-mkdoc.html)

Here an example of an embedded mkdoc comment for a Python script:

```python

#' **hw()**
#'  
#' > Function prints "Hello World!" to the terminal!"
#'  
#' > Arguments: 
#'  
#' > - _n_ - how often the string "Hello World!" should be printed, default: 3 
#'  
#' > Returns: None
#'  
#' > Example:
#'  
#' ```
#' hw(5)
#' ```
#'   
def hw(n=3):
    for i in range(0,n):  
       print("Hello World!")
    
```

Markdown documentation comments for programming languages which have not the hash character as a comment character can be embedded using multliline comments. Here an example for a C or C++ programm:

```c
/*
#' **void hw(int n);**
#' ...
*/
void hw(int n) {
    int i = 0;
    for (i = 0 ; i < n; i=i+1) {
        printf("Hello World!\n");
    }
}
```   

A more extended example can be seen within the script
[mkdoc/mkdoc.tcl](https://github.com/mittelmark/mkdoc/blob/main/mkdoc/mkdoc.tcl)
itself. These comments are used to create the longer manual which can be seen here: [mkdoc-mkdoc.html](http://htmlpreview.github.io/?https://github.com/mittelmark/mkdoc/blob/master/mkdoc/mkdoc-mkdoc.html).


  
