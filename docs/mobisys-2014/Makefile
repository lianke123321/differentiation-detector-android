LATEX= pdflatex
BIBTEX= bibtex

MAINDOC = meddle-main
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
