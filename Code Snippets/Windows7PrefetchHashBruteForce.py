def bruteforce(start, end):
        start=start * 803794207
        h=ord("\\")
        for a in range(65, 91):
         for b in range(65, 91):
          for c in range(65, 91):
           for d in range(65, 91):
            y = (37*d + 50653*c + 69343957*b + 442596621*a - start) % 4294967296 * 803794207
            for e in range(65, 91):
             for f in range(65, 91):
              for g in range(65, 91):
               z = (37*h + 50653*g + 69343957*f + 442596621*e - y) % 4294967296
               if end == z:
                print chr(a)+chr(b)+chr(c)+chr(d)+chr(e)+chr(f)+chr(g)+chr(h)

bruteforce(4153493455, 2151503994)

