# sane targets
DOCN = main

all: doc
doc:
	pdflatex $(DOCN).tex
	pdflatex $(DOCN).tex
	bibtex $(DOCN)
	pdflatex $(DOCN).tex
#	pdffonts $(DOCN).pdf

clean:
	rm -f *.aux *.dvi *.idx *.ind *.log *.toc *.bak *.blg *.bbl 
	rm -f *.pdf *.ps *~

# Tell versions [3.59,3.63) of GNU make to not export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
