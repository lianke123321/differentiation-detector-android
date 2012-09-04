#ifndef LOGGING_H_
#define LOGGING_H_

#include <iostream>

#if 0
#define logDebug(msg) do {				\
	std::cout << msg << std::endl;	\
} while (0);
#else
#define logDebug(msg) do {} while (0);
#endif


#if 1
#define logError(msg) do {				\
	std::cout << msg << std::endl;	\
} while (0);
#else
#define logError(msg) do {} while (0);
#endif

#endif /* LOGGING_H_ */
