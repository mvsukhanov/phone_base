begin;
	select tap.plan(2);
	insert into administrator_schema.tariff(price, phone_tariff) values
		('10', 'test');
	insert into administrator_schema.subscribers(name, surname, phone_number, balance, 
		phone_tariff, login) values 
		('test', 'test', 'test_one', '100', 'test', 'superuser');
	insert into administrator_schema.subscribers(name, surname, phone_number, balance, 
		phone_tariff, login) values 
		('test', 'test', 'test_two', '100', 'test', 'superuser');
	call subscriber_schema.transfer_money('test_one', 'test_two', '50');
	select tap.ok((select balance from administrator_schema.subscribers 
		where phone_number = 'test_one') = '50',
	 	'test procedure transfer_money faild');
	select tap.ok((select balance from administrator_schema.subscribers 
		where phone_number = 'test_two') = '150',
	 	'test procedure transfer_money faild');
	select * from tap.finish();
rollback;