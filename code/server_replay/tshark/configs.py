class Configs(object):
    _instance = None
    _configs = {}
    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super(Configs, cls).__new__(cls, *args, **kwargs)
        return cls._instance
    
    @staticmethod
    def set(key, value):
        Configs._configs[key] = value
    @staticmethod
    def get(key):
        return Configs._configs[key]
    
    
class kir(object):
    def __init__(self, kos):
        print kos
    def abmaghz(self, kos):
        print kos
        
t = threading.Thread(target=kir('to').abmaghz, args=['bere'])
t.start()
