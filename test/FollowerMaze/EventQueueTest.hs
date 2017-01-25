module FollowerMaze.EventQueueTest
  ( eventQueueTests
  ) where

import FollowerMaze.Event (Event, SequenceNumber, eventRaw)
import FollowerMaze.EventQueue (EventQueue (EventQueue), dequeueAll)
import FollowerMaze.Test.Generators (eventQueue)

import Test.Tasty
import qualified Test.Tasty.QuickCheck as QC

-- | High-level tests of `EventQueue` behavior.
eventQueueTests :: TestTree
eventQueueTests = testGroup "EventQueue" [dequeueAllTests]

-- | Internal only. Input queues for `dequeueAll`'s tests are generated by
-- `FollowerMaze.Test.Generators.eventQueue`, which uses `enqueueRaw`
-- to build up loaded queues.
dequeueAllTests:: TestTree
dequeueAllTests = testGroup "dequeueAll" [dequeueAllProps]

-- | Internal only. Invariant properties of the `dequeueAll` operation.
dequeueAllProps :: TestTree
dequeueAllProps = testGroup "Properties"
  [ QC.testProperty "dequeues events in non-decreasing sequence"   propDequeueAllNonDecreasing
  , QC.testProperty "next sequence # is larger than last dequeued" propDequeueAllNonemptyNextLarger
  , QC.testProperty "next sequence # is same after empty dequeue"  propDequeueAllEmptyNextSame
  , QC.testProperty "second dequeue in a row is empty"             propDequeueAllTwiceEmpty
  ]

propDequeueAllNonDecreasing :: QC.Property
propDequeueAllNonDecreasing =
  QC.forAll eventQueue $ isNonDecreasingSequenceNumber . fst . dequeueAll
      where
  isNonDecreasingSequenceNumber :: [Event] -> Bool
  isNonDecreasingSequenceNumber = isNonDecreasing . map sequenceNumber
  isNonDecreasing :: Ord a => [a] -> Bool
  isNonDecreasing = and . (zipWith (<=) <*> tail)

propDequeueAllNonemptyNextLarger :: QC.Property
propDequeueAllNonemptyNextLarger =
  QC.forAll eventQueue $ nextExpectedLarger . dequeueAll
      where
  nextExpectedLarger :: ([Event], EventQueue) -> Bool
  nextExpectedLarger ([], _             ) = True
  nextExpectedLarger (es, EventQueue n _) = sequenceNumber (last es) < n

propDequeueAllEmptyNextSame :: QC.Property
propDequeueAllEmptyNextSame =
  QC.forAll eventQueue $
    \q@(EventQueue oldN _) -> queueNextPreserved oldN $ dequeueAll q
      where
  queueNextPreserved :: SequenceNumber -> ([Event], EventQueue) -> Bool
  queueNextPreserved n ([], EventQueue n' _) = n == n'
  queueNextPreserved _ _                     = True

propDequeueAllTwiceEmpty :: QC.Property
propDequeueAllTwiceEmpty =
  QC.forAll eventQueue $ null . fst . dequeueAll . snd . dequeueAll

-- | Internal only. Returns the sequence number from the raw representation
-- stored in an `Event`.
--
-- Development and testing only.
-- __Unsafe__ for `Event`s containing malformed raw events.
sequenceNumber :: Event -> SequenceNumber
sequenceNumber = read . takeWhile (/= '|') . eventRaw
