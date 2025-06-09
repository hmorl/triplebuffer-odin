package tb

import "core:sync"
import "core:thread"

Triple_Buffer :: struct($T: typeid) {
	data:        [3]T,
	write_index: u8,
	read_index:  u8,
	snapshot:    Snapshot,
}

Snapshot :: bit_field u8 {
	index:  u8   | 2,
	is_new: bool | 1,
}

init :: proc(tb: ^Triple_Buffer($T)) {
	tb.write_index = 0
	tb.read_index = 1
	tb.snapshot.index = 2
	tb.snapshot.is_new = true
}

init_explicit :: proc(tb: ^Triple_Buffer($T), initial_value: T) {
	init(tb)
	tb.data[tb.snapshot.index] = initial_value
}

write :: proc(tb: ^Triple_Buffer($T), value: T) {
	tb.data[tb.write_index] = value

	prev_snapshot := sync.atomic_exchange_explicit(
		&tb.snapshot,
		Snapshot{index = tb.write_index, is_new = true},
		sync.Atomic_Memory_Order.Acq_Rel,
	)

	tb.write_index = prev_snapshot.index
}

read :: proc(tb: ^Triple_Buffer($T)) -> (^T, bool) {
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
