begin;
	select tap.plan(4);	
	insert into tariff(price, phone_tariff) values ('10000', 'test');
	select tap.alike((select phone_tariff from manager_schema.select_from_tariff('test') 
		where price = '10000'), 'test', 
		'function select_from_tariff faild');
	select tap.alike((select phone_tariff from manager_schema.select_from_tariff('test') 
		where price = '10000'), '%st', 
		'function select_from_tariff faild');
	select tap.alike((select phone_tariff from manager_schema.select_from_tariff('test') 
		where price = '10000'), 'te%', 
		'function select_from_tariff faild');
	select tap.alike((select phone_tariff from manager_schema.select_from_tariff('test') 
		where price = '10000'), '%es%', 
		'function select_from_tariff faild');
	select * from tap.finish();
rollback;