begin;
	select tap.plan(6);
	insert into tariff(price, phone_tariff) values
		('10', 'test');
	insert into subscribers(name, surname, phone_number, balance, phone_tariff) values
		('test', 'test', 'test', '100', 'test');
	call insert_call_list('test', 'uncnown', '27.07.2022', '19:42:00', '00:01:00');

	select tap.ok((select outgoing_phone_number from phone_station_schema.call_list_view
		where outgoing_phone_number = 'test') = 'test', 'procedure inset_call_list faild');
	select tap.ok((select incoming_phone_number from phone_station_schema.call_list_view
		where outgoing_phone_number = 'test') = 'uncnown', 'procedure inset_call_list faild');
	select tap.ok((select call_date from phone_station_schema.call_list_view
		where outgoing_phone_number = 'test') = '27.07.2022', 'procedure inset_call_list faild');
	select tap.ok((select call_time from phone_station_schema.call_list_view
		where outgoing_phone_number = 'test') = '19:42:00', 'procedure inset_call_list faild');
	select tap.ok((select call_interval from phone_station_schema.call_list_view
		where outgoing_phone_number = 'test') = '00:01:00', 'procedure inset_call_list faild');

	select tap.ok((select balance from subscribers
		where phone_number = 'test') = '90', 'trigger call_pay faild');

	select * from tap.finish();

rollback;