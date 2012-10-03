#ifndef MACROS_H
#define MACROS_H

#define TAKE_SCOPED_LOCK(lock) boost::mutex::scoped_lock scoped_lock(lock);

#endif
