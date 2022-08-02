begin;
	select tap.plan(6);	
	insert into tariff(price, phone_tariff) values ('10', 'test');
	call manager_schema.insert_subscriber('test', 'test', 'test', 'test', '10');
	select tap.ok((select name from subscribers where phone_number = 'test') = 'test'
		, 'procedure insert_subscribers faild');
	select tap.ok((select surname from subscribers where phone_number = 'test') = 'test'
		, 'procedure insert_subscribers faild');
	select tap.ok((select phone_number from subscribers where phone_number = 'test') = 'test'
		, 'procedure insert_subscribers faild');
	select tap.ok((select phone_tariff from subscribers where phone_number = 'test') = 'test'
		, 'procedure insert_subscribers faild');
	select tap.ok((select balance from subscribers where phone_number = 'test') = '10'
		, 'procedure insert_subscribers faild');
	select tap.ok((select minutes_to_call from subscribers where phone_number = 'test') = '00:01:00'
		, 'procedure insert_subscribers or trigger function refresh_minutes faild');
	select * from tap.finish();
rollback;