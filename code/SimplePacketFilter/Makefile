CXXFLAGS = -O3 -g -Wall -fmessage-length=0
LIBS= -lboost_thread  -lboost_date_time
SRC = $(wildcard $(PWD)/*.cc)
OBJS = $(SRC:.cc=.o)
TARGET = SimplePacketFilter

$(TARGET): clean $(OBJS)
	$(CXX)  -o $(TARGET) $(OBJS) $(LIBS) 
	
%.o : %.cc
	$(CXX) $(LIBS) $(CFLAGS) -c $<
	
all: $(TARGET)

distclean: clean
	rm -f $(TARGET)	

clean:
	rm -f $(OBJS)
