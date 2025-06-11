package tb

import "core:sync"
import "core:thread"

Triple_Buffer :: struct($T: typeid) {
	data:        [3]T,
	write_index: u8,
	read_index:  u8,
	snapshot:    Snapshot,
}

/*
	Initialises a Triple_Buffer (with a zero value).

	`init` (or `init_explicit`) should be called before calling any other procedure.
*/
init :: proc(tb: ^Triple_Buffer($T)) {
	tb.write_index = 0
	tb.read_index = 1
	tb.snapshot.index = 2
	tb.snapshot.is_new = true
}

/*
	Initialises a Triple_Buffer (with an explicit value).

	`init_explicit` (or `init`) should be called before calling any other procedure.
*/
init_explicit :: proc(tb: ^Triple_Buffer($T), initial_value: T) {
	init(tb)
	tb.data[tb.snapshot.index] = initial_value
}

/*
	Returns a pointer to the current write buffer. Use this to write
	incrementally into the buffer, particularly if the data is an array-like
	structure. Call `publish` to make the changes available to the reader.

	See also: `publish_value`, to write and publish in one operation.

	This procedure should only be used by the writer/producer thread.
*/
get_write_ptr :: proc(tb: ^Triple_Buffer($T)) -> ^T {
	return &tb.data[tb.write_index]
}

/*
	Swaps the current write buffer with the snapshot buffer
	to make the newly written data available to the reader. 

	This procedure should only be used by the writer/producer thread.
*/
publish :: proc(tb: ^Triple_Buffer($T)) {
	prev_snapshot := sync.atomic_exchange_explicit(
		&tb.snapshot,
		Snapshot{index = tb.write_index, is_new = true},
		sync.Atomic_Memory_Order.Acq_Rel,
	)

	tb.write_index = prev_snapshot.index
}

/*
	Write and publish in one call, for convenience.

	See also: `get_write_ptr` and `publish`, if you need to write
	incrementally.

	This procedure should only be used by the writer/producer thread.
*/
publish_value :: proc(tb: ^Triple_Buffer($T), value: T) {
	get_write_ptr(tb)^ = value
	publish(tb)
}

/*
	Swaps the snapshot buffer with the read buffer to make the recently
	published data available to the reader. Also returns a boolean to indicate
	whether the data has changed since the last read.

	This procedure should only be used by the reader/consumer thread.
*/
read :: proc(tb: ^Triple_Buffer($T)) -> (data: ^T, is_new: bool) {
	snapshot := sync.atomic_load_explicit(&tb.snapshot, sync.Atomic_Memory_Order.Acquire)

	if !snapshot.is_new {
		return &tb.data[tb.read_index], false
	}

	prev_snapshot: Snapshot
	swap_succeeded: bool

	for retries := 0; !swap_succeeded && retries < 99; retries += 1 {
		snapshot = sync.atomic_load_explicit(&tb.snapshot, sync.Atomic_Memory_Order.Acquire)

		prev_snapshot, swap_succeeded = sync.atomic_compare_exchange_strong_explicit(
			&tb.snapshot,
			snapshot,
			Snapshot{index = tb.read_index, is_new = false},
			sync.Atomic_Memory_Order.Acq_Rel,
			sync.Atomic_Memory_Order.Acquire,
		)

		if !swap_succeeded {
			thread.yield()
		}
	}

	if !swap_succeeded {
		return &tb.data[tb.read_index], false
	}

	tb.read_index = prev_snapshot.index
	return &tb.data[tb.read_index], true
}

/*
	This is used internally to set both the snapshot index and the "is new"
	flag in one atomic operation.
*/
Snapshot :: bit_field u8 {
	index:  u8   | 2,
	is_new: bool | 1,
}
