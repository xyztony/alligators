type
  Region* = object of RootObj
    next*: ptr Region
    count*: int
    capacity*: int

  Arena* = object
    begin*: ptr Region
    `end`*: ptr Region

const REGION_CAP_DEF = sizeof(uint64) * 1024 # ==> 8 * 1024

proc newRegion(cap: int): ptr Region =
  var region: ptr Region = cast[ptr Region](
    allocShared0(sizeof(Region) + sizeof(uint)*cap)
  )
  region[].capacity = cap
  region[].count = 0
  region[].next = nil
  return region

proc freeRegion(r: ptr Region) = deallocShared(r)

proc arenaAlloc*(a: ptr Arena, size: int): pointer {.discardable.} =
  if isNil(a[].`end`):
    assert(isNil(a[].begin))
    let capacity = if REGION_CAP_DEF < size: size else: REGION_CAP_DEF
    a[].`end` = newRegion(capacity)
    a[].begin = a[].`end`

  while a[].`end`.count + size > a[].`end`.capacity and not isNil(a[].`end`.next):
    a[].`end` = a[].`end`.next

  if a[].`end`.count + size > a[].`end`.capacity:
    assert(isNil(a[].`end`.next))
    let capacity = if REGION_CAP_DEF < size: size else: REGION_CAP_DEF
    a[].`end`.next = newRegion(capacity)
    a[].`end` = a[].`end`.next

  result = addr a[].`end`
  inc(a[].`end`.count, size)

proc arenaRealloc*(a: ptr Arena, prevPointer: pointer, oldSize: int, newSize: int): pointer =
  if newSize <= oldSize : return prevPointer

  var newPointer = arenaAlloc(a, newSize)
  copyMem(newPointer, prevPointer, oldSize)
  return newPointer

proc arenaReset*(a: ptr Arena) =
  var r = a[].begin
  while not isNil(r):
    r.count = 0
    r = r.next
  a[].`end` = a[].begin

proc arenaFree*(a: ptr Arena) =
  var r: ptr Region = a[].begin
  while not isNil(r):
    var regionToFree: ptr Region = r
    r = r[].next
    freeRegion(regionToFree)
  a[].`end` = nil