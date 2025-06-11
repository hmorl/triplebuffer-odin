package test

import tb "../"
import "core:sync"
import "core:testing"
import "core:thread"
import "core:time"

@(test)
test_tb_init :: proc(t: ^testing.T) {
	buffer: tb.Triple_Buffer(int)

	tb.init(&buffer)

	value, is_new := tb.read(&buffer)
	testing.expect_value(t, value^, 0)
	testing.expect_value(t, is_new, true)
}

@(test)
test_tb_init_explicit :: proc(t: ^testing.T) {
	buffer: tb.Triple_Buffer(int)

	tb.init_explicit(&buffer, 42)

	value, is_new := tb.read(&buffer)
	testing.expect_value(t, value^, 42)
	testing.expect_value(t, is_new, true)
}

@(test)
test_tb_single_threaded :: proc(t: ^testing.T) {
	buffer: tb.Triple_Buffer(int)
	tb.init(&buffer)

	tb.publish_value(&buffer, 42)

	value, is_new := tb.read(&buffer)
	testing.expect_value(t, value^, 42)
	testing.expect_value(t, is_new, true)

	value, is_new = tb.read(&buffer)
	testing.expect_value(t, value^, 42)
	testing.expect_value(t, is_new, false)

	tb.publish_value(&buffer, 32)
	tb.publish_value(&buffer, 13)
	tb.publish_value(&buffer, 999)

	value, is_new = tb.read(&buffer)
	testing.expect_value(t, value^, 999)
	testing.expect_value(t, is_new, true)

	tb.read(&buffer)
	tb.read(&buffer)
	value, is_new = tb.read(&buffer)

	testing.expect_value(t, value^, 999)
	testing.expect_value(t, is_new, false)
}

Read_Entry :: struct {
	value:   int,
	was_new: bool,
}

Thread_Data :: struct {
	buffer:            tb.Triple_Buffer(int),
	producer_finished: sync.One_Shot_Event,
	consumer_quit:     bool,
	consumer_finished: sync.One_Shot_Event,
	consumer_data:     [dynamic]Read_Entry,
}

producer_proc :: proc(data: ^Thread_Data, interval: time.Duration) {
	for i in 1 ..= 500 {
		tb.get_write_ptr(&data.buffer)^ = i
		tb.publish(&data.buffer)
		time.sleep(interval)
	}

	sync.one_shot_event_signal(&data.producer_finished)
}

consumer_proc :: proc(data: ^Thread_Data, interval: time.Duration) {
	for !sync.atomic_load(&data.consumer_quit) {
		value_ptr, is_new := tb.read(&data.buffer)
		entry := append(&data.consumer_data, Read_Entry{value_ptr^, is_new})
		time.sleep(interval)
	}

	sync.one_shot_event_signal(&data.consumer_finished)
}

test_tb_multithreaded :: proc(t: ^testing.T, producer_interval, consumer_interval: time.Duration) {
	data: Thread_Data

	tb.init(&data.buffer)

	producer_thread, consumer_thread :=
		thread.create_and_start_with_poly_data2(&data, producer_interval, producer_proc),
		thread.create_and_start_with_poly_data2(&data, consumer_interval, consumer_proc)

	sync.one_shot_event_wait(&data.producer_finished)

	sync.atomic_store(&data.consumer_quit, true)
	sync.one_shot_event_wait(&data.consumer_finished)

	prev_value := -1
	for entry in data.consumer_data {
		testing.expect_value(t, entry.was_new, entry.value != prev_value)
		testing.expect(t, entry.value >= prev_value)
		prev_value = entry.value
	}

	thread.join_multiple(producer_thread, consumer_thread)
	thread.destroy(producer_thread)
	thread.destroy(consumer_thread)
}

@(test)
test_tb_multithreaded_fast_producer :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, time.Second * 5)

	PRODUCER_INTERVAL :: time.Microsecond * 50
	CONSUMER_INTERVAL :: time.Microsecond * 100
	test_tb_multithreaded(t, PRODUCER_INTERVAL, CONSUMER_INTERVAL)
}

@(test)
test_multithreaded_fast_consumer :: proc(t: ^testing.T) {
	testing.set_fail_timeout(t, time.Second * 5)

	PRODUCER_INTERVAL :: time.Microsecond * 100
	CONSUMER_INTERVAL :: time.Microsecond * 50
	test_tb_multithreaded(t, PRODUCER_INTERVAL, CONSUMER_INTERVAL)
}
