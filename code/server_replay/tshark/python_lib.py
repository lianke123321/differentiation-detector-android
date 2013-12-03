import socket, sys, subprocess, commands, os, ConfigParser

def PRINT_ACTION(string, indent, action=True):
    if action:
        print ''.join(['\t']*indent), '[' + str(Configs().get('action_count')) + ']' + string
        Configs().set('action_count', Configs().get('action_count') + 1)
    else:
        print ''.join(['\t']*indent) + string
def read_args(args, configs):
    for arg in args:
        a = (arg.strip()).partition('=')
        configs.set(a[0], a[2])
def append_to_file(line, filename):
    f = open(filename, 'a')
    f.write((line + '\n'))
    f.close()
def dir_list(dir_name, subdir, *args):
    '''
    Return a list of file names in directory 'dir_name'
    If 'subdir' is True, recursively access subdirectories under 'dir_name'.
    Additional arguments, if any, are file extensions to add to the list.
    Example usage: fileList = dir_list(r'H:\TEMP', False, 'txt', 'py', 'dat', 'log', 'jpg')
    '''
    fileList = []
    for file in os.listdir(dir_name):
        dirfile = os.path.join(dir_name, file)
        if os.path.isfile(dirfile):
            if len(args) == 0:
                fileList.append(dirfile)
            else:
                if os.path.splitext(dirfile)[1][1:] in args:
                    fileList.append(dirfile)
        # recursively access file names in subdirectories
        elif os.path.isdir(dirfile) and subdir:
            # print "Accessing directory:", dirfile
            fileList += dir_list(dirfile, subdir, *args)
    return fileList
class RequestSet(object):
    def __init__(self, payload, c_s_pair, response, timestamp):
        self.payload  = payload
        self.c_s_pair = c_s_pair
        if response is None:
            self.response_hash = None
            self.response_len  = 0
        else:    
            self.response_hash = hash(response)
            self.response_len  = len(response)
        self.timestamp = timestamp
class ResponseSet(object):
    def __init__(self, request, response_list):
        self.request_len   = len(request)
        self.request_hash  = hash(request)
        self.response_list = response_list
class OneResponse(object):
    def __init__(self, payload, timestamp):
        self.payload   = payload
        self.timestamp = timestamp
class Singleton(type):
    _instances = {}
    def __call__(cls, *args, **kwargs):
        if cls not in cls._instances:
            cls._instances[cls] = super(Singleton, cls).__call__(*args, **kwargs)
        return cls._instances[cls]
class Configs(object):
    __metaclass__ = Singleton
    _Config       = None
    _configs      = {}
    def __init__(self, config_file = None):
        self._Config = ConfigParser.ConfigParser()
        self._configs['action_count'] = 0
        if config_file != None:
            read_config_file(config_file)
    def read_config_file(self, config_file):
        self._Config.read(config_file)
        for section in self._Config.sections():
            for option in self._Config.options(section):
                self._configs[option] = self._Config.get(section, option)
    def get(self, key):
        return self._configs[key]
    def set(self, key, value):
        self._configs[key] = value
    def show(self, key):
        print key , ':\t', value
    def show_all(self):
        for key in self._configs:
            print '\t', key , ':\t', self._configs[key]
