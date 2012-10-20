#ifndef LOGGING_H_
#define LOGGING_H_

#include <iostream>
#include <time.h>

#if 1
#define logDebug(msg) do {				\
	std::cout << time(NULL) << ":DBG:" << __FILE__ << ":" << __func__ << ":"<<  __LINE__ << ":" << msg << std::endl;	\
} while (0);
#else
#define logDebug(msg) do {} while (0);
#endif


#if 1
#define logError(msg) do {				\
	std::cout << time(NULL) << ":ERR:" << __FILE__ << ":"<< __func__ << ":"<< __LINE__ << ":" << msg << std::endl;	\
} while (0);
#else
#define logError(msg) do {} while (0);
#endif

#if 1
#define logInfo(msg) do {				\
	std::cout << time(NULL) << ":INFO:" << __FILE__ << ":"<< __func__ << ":"<< __LINE__ << ":" << msg << std::endl;	\
} while (0);
#else
#define logInfo(msg) do {} while (0);
#endif

#endif /* LOGGING_H_ */
