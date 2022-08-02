begin;
	select tap.plan(1);
	insert into tariff(price, phone_tariff) values ('10', 'test');
	insert into phone_station_schema.subscribers_view (name, surname, phone_number, balance, phone_tariff)
		values ('test', 'test', 'test', '10', 'test');
	select tap.ok((select minutes_to_call from phone_station_schema.subscribers_view 
		where phone_number = 'test') = '00:01:00', 
		'function_select_minutes_to_call_from_subscribers faild');
	select * from tap.finish();
rollback;