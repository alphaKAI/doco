#doco
Yet another fuzzy text selector.  
This software is inspired by [peco](https://github.com/peco/peco).  
peco is written in Go, a software like peco written in D haven't existed thus I made.  
peco doesn't support regex as a search query but doco supports filtering by regex query(by default)!  

#Note
Current version doesn't support multibyte character.    
This problem is caused by `termbox`.  
This program depends on `termbox-d` and `termbox-d` depends on `termbox`.    
`termbox` doesn't support multibyte character.  
I'll fix this problem by implementing original CLI tool kit for D.   

#LICENSE
doco is relased under the MIT license.  
Please see `LICENSE` file for details.  
