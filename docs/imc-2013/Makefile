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

MAINDOC = main
MAINPDF = ${MAINDOC}.pdf

all: clean
	${LATEX} ${MAINDOC}.tex
	${BIBTEX} ${MAINDOC}.aux
	${LATEX} ${MAINDOC}.tex
	${LATEX} ${MAINDOC}.tex

clean:
	rm -f *aux *bbl *blg *log *.tex~ *.dvi *.fdb_lat* *.fls 
#	rm -f ${MAINDOC}.pdf
	rm -Rf auto/ 
