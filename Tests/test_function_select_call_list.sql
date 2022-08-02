begin;
	select tap.plan(3);
	insert into administrator_schema.tariff(price, phone_tariff) values
		('10', 'test');
	insert into administrator_schema.subscribers(name, surname, phone_number, balance, 
		phone_tariff, login) values 
		('test', 'test', 'test_one', '10', 'test', 'superuser');
	insert into administrator_schema.subscribers(name, surname, phone_number, balance, 
		phone_tariff, login) values 
		('test', 'test', 'test_two', '10', 'test', 'superuser');
	insert into administrator_schema.call_list(outgoing_phone_number, call_date, call_time, 
		call_interval, incoming_phone_number) values 
		('test_one', '30.05.2022', '10:10:10', '00:01:00', 'test_two');
	insert into administrator_schema.call_list(outgoing_phone_number, call_date, call_time, 
		call_interval, incoming_phone_number) values 
		('test_one', '30.06.2022', '10:10:10', '00:01:00', 'test_two');
	insert into administrator_schema.call_list(outgoing_phone_number, call_date, call_time, 
		call_interval, incoming_phone_number) values 
		('test_one', '30.07.2022', '10:10:10', '00:01:00', 'test_two');
	select tap.ok((select call_date from subscriber_schema.select_call_list
		('10.06.2022', '10.07.2022', 'test_one')) = 
		'30.06.2022', 'test function select_call_list faild');
	select tap.ok((select call_date from subscriber_schema.select_call_list
		('10.06.2022', '10.07.2022', 'test_two')) = 
		'30.06.2022', 'test function select_call_list faild');
	select tap.ok((select count(*) from subscriber_schema.select_call_list
		('10.04.2022', '10.08.2022', 'test_two')) = 
		3, 'test function select_call_list faild');
	select * from tap.finish();
rollback;