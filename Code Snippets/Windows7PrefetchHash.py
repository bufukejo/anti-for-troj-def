def hashw7(filepath):
        
        #Convert filepath to unicode + uppercase
        path=""
        for character in filepath:
                path += character.upper() + '\x00'
        
        #Windows' algorithm begins here
        hash=314159
        numof8 = int(len(path)/8)
        
        #For the majority of the path, the string is processed in 8-byte chunks
        for i in range(0, numof8):
                char0 = ord(path[i*8+0])
                char1 = ord(path[i*8+1])
                char2 = ord(path[i*8+2])
                char3 = ord(path[i*8+3])
                char4 = ord(path[i*8+4])
                char5 = ord(path[i*8+5])
                char6 = ord(path[i*8+6])
                char7 = ord(path[i*8+7])
                hash = (442596621* char0 + 37*(char6 + 37*(char5 + 37*(char4 + 37*(char3 + 37*(char2 + 37*char1))))) - 803794207*hash + char7) % 4294967296
                
                #Print the hash at the current part of the string
                print path[i*8:i*8+8], hash
        
        #The final <8 bytes are processed with this similar algorithm
        for k in range(0, len(path) % 8):
                hash = (37*hash+ord(path[numof8*8+k]))  % 4294967296
        
        #The hash is returned as a hex string
        return hex(hash).split('x')[1]


print hashw7('\\DEVICE\\HARDDISKVOLUME2\\WINDOWS\\EXPLORER.EXE')

