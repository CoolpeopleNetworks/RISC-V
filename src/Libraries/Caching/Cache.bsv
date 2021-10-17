import Memory::*;

interface Cache#(numeric type logNLines);
    interface MemoryServer#(32, 32) cacheMemoryServer;
    interface MemoryClient#(512, 512) mainMemoryClient;
endinterface
