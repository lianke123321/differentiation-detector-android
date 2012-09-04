CXXFLAGS = -O3 -g -Wall -fmessage-length=0
LIBS=
SRC = $(wildcard *.cc)
OBJS = $(SRC:.cc=.o)
TARGET = SimplePacketFilter

$(TARGET): clean $(OBJS)
	$(CXX) -o $(TARGET) $(OBJS) $(LIBS)
	
%.o : %.cc
	$(CXX) $(CFLAGS) -c $<
	
all: $(TARGET)

distclean: clean
	rm -f $(TARGET)	

clean:
	rm -f $(OBJS)
