begin;
	select tap.plan(1);
	insert into tariff(price, phone_tariff) values ('10', 'test');
	insert into manager_schema.subscribers_view(name, surname, phone_number, balance, phone_tariff) 
	values ('test', 'test', 'test', '0', 'test');
	call add_money('10', 'test');
	select tap.ok((select balance from manager_schema.subscribers_view where phone_number = 'test') 
		= '10', 'procedure add_money faild');
	select * from tap.finish();
rollback;