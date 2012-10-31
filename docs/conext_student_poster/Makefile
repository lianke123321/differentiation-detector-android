# sane targets
DOCN = main-camera

all: doc
doc:
	latex $(DOCN).tex
	latex $(DOCN).tex
	bibtex $(DOCN)
	latex $(DOCN).tex
	latex $(DOCN).tex
	dvips -P pdf -t letter -o $(DOCN).ps $(DOCN).dvi        

clean:
	rm -f *.aux *.dvi *.idx *.ind *.log *.toc *.bak *.blg *.bbl
	rm -f *.pdf *.ps

# Tell versions [3.59,3.63) of GNU make to not export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
