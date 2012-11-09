LATEX= pdflatex
BIBTEX= bibtex
XDVI = xdvi
DVIPDF= dvipdfm -p letter
PS2PDF= ps2pdf
DVIPS= dvips -t letter -P pdf
RM = /bin/rm -f
CAT = cat
ISPELL = ispell
SORT = sort

MAINDOC = hotnets-meddle-middle
MAINPDF = ${MAINDOC}.pdf

all:
	${LATEX} ${MAINDOC}.tex
	${BIBTEX} ${MAINDOC}.aux
	${LATEX} ${MAINDOC}.tex
	${LATEX} ${MAINDOC}.tex

clean:
	rm *aux *bbl *blg *log 
