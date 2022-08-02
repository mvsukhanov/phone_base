--
-- PostgreSQL database dump
--

-- Dumped from database version 14.2
-- Dumped by pg_dump version 14.2

-- Started on 2022-08-02 16:11:00

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 9 (class 2615 OID 49668)
-- Name: administrator_schema; Type: SCHEMA; Schema: -; Owner: administrator
--

CREATE SCHEMA administrator_schema;


ALTER SCHEMA administrator_schema OWNER TO administrator;

--
-- TOC entry 6 (class 2615 OID 49735)
-- Name: manager_schema; Type: SCHEMA; Schema: -; Owner: administrator
--

CREATE SCHEMA manager_schema;


ALTER SCHEMA manager_schema OWNER TO administrator;

--
-- TOC entry 7 (class 2615 OID 49790)
-- Name: phone_station_schema; Type: SCHEMA; Schema: -; Owner: administrator
--

CREATE SCHEMA phone_station_schema;


ALTER SCHEMA phone_station_schema OWNER TO administrator;

--
-- TOC entry 8 (class 2615 OID 49740)
-- Name: subscriber_schema; Type: SCHEMA; Schema: -; Owner: administrator
--

CREATE SCHEMA subscriber_schema;


ALTER SCHEMA subscriber_schema OWNER TO administrator;

--
-- TOC entry 10 (class 2615 OID 51134)
-- Name: tap; Type: SCHEMA; Schema: -; Owner: administrator
--

CREATE SCHEMA tap;


ALTER SCHEMA tap OWNER TO administrator;

--
-- TOC entry 2 (class 3079 OID 52426)
-- Name: pgtap; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA tap;


--
-- TOC entry 4516 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgtap; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgtap IS 'Unit testing for PostgreSQL';


--
-- TOC entry 287 (class 1255 OID 50030)
-- Name: call_pay(); Type: FUNCTION; Schema: administrator_schema; Owner: administrator
--

CREATE FUNCTION administrator_schema.call_pay() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	begin
		update subscribers_view set balance = balance - (select (extract (epoch from new.call_interval) / 60)) * 
        (select price from tariff_view where phone_tariff = (select phone_tariff from subscribers_view where phone_number = new.outgoing_phone_number))
		where phone_number = new.outgoing_phone_number;
        return new;
	end;
$$;


ALTER FUNCTION administrator_schema.call_pay() OWNER TO administrator;

--
-- TOC entry 4517 (class 0 OID 0)
-- Dependencies: 287
-- Name: FUNCTION call_pay(); Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON FUNCTION administrator_schema.call_pay() IS 'После insert в call_list производит списание денег с исходящего номера';


--
-- TOC entry 283 (class 1255 OID 49788)
-- Name: refresh_minutes(); Type: FUNCTION; Schema: administrator_schema; Owner: administrator
--

CREATE FUNCTION administrator_schema.refresh_minutes() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin
	new.minutes_to_call = 
	(new.balance / (select price from administrator_schema.tariff where phone_tariff = new.phone_tariff) * '00:01:00'::interval);
    return new;
    end;
$$;


ALTER FUNCTION administrator_schema.refresh_minutes() OWNER TO administrator;

--
-- TOC entry 4518 (class 0 OID 0)
-- Dependencies: 283
-- Name: FUNCTION refresh_minutes(); Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON FUNCTION administrator_schema.refresh_minutes() IS 'Обновляет столбец minutes_to_call в subscribers, в зависимости от изменения баланса клиентов';


--
-- TOC entry 286 (class 1255 OID 50015)
-- Name: transfer_money_first(); Type: FUNCTION; Schema: administrator_schema; Owner: administrator
--

CREATE FUNCTION administrator_schema.transfer_money_first() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	begin
		if new.transfer_out not in (select phone_number from subscriber_schema.subscribers_view where login = CURRENT_USER)
        then raise exception 'Некорректный номер, с которого осуществляется перевод';
        elsif new.summ >= (select balance from subscriber_schema.subscribers_view where new.transfer_out = phone_number)
		then raise exception 'Недостаточно средств';
        elsif new.summ < '10'
		then raise exception 'Минимальная сумма перевода 10 рублей';
		end if;
        return new;
	end;
$$;


ALTER FUNCTION administrator_schema.transfer_money_first() OWNER TO administrator;

--
-- TOC entry 4520 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION transfer_money_first(); Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON FUNCTION administrator_schema.transfer_money_first() IS 'Функция для добавления строк в таблицу transfer_money для перевода средств между номерами.
Проверяет подключенного пользователя на возможность доступа к данным в зависимости от присвоенного пользователю номеру телефона. А так же проверяет наличие денежных средств для перевода и минимальное значение перевода 10 рублей.
Запускается с правами пользователя.';


--
-- TOC entry 285 (class 1255 OID 50016)
-- Name: transfer_money_second(); Type: FUNCTION; Schema: administrator_schema; Owner: administrator
--

CREATE FUNCTION administrator_schema.transfer_money_second() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
	begin
		if (select phone_number from administrator_schema.subscribers where phone_number = new.transfer_in) isnull
        then raise exception 'Номер для перевода не существует';
        elsif new.transfer_in = new.transfer_out
        then raise exception 'Нельзя переводить самому себе';
        end if;
        update administrator_schema.subscribers set balance = balance - new.summ where phone_number = new.transfer_out;
		update administrator_schema.subscribers set balance = balance + new.summ where phone_number = new.transfer_in;
        return new;
	end;
$$;


ALTER FUNCTION administrator_schema.transfer_money_second() OWNER TO administrator;

--
-- TOC entry 4522 (class 0 OID 0)
-- Dependencies: 285
-- Name: FUNCTION transfer_money_second(); Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON FUNCTION administrator_schema.transfer_money_second() IS 'Проверяется наличие номера для перевода и запрещает переводить самому себе.
После добавления строк в таблицу transfer_money осуществляет перевод средств. Запускается с правами администратора.';


--
-- TOC entry 281 (class 1255 OID 49762)
-- Name: add_money(money, character varying); Type: PROCEDURE; Schema: manager_schema; Owner: administrator
--

CREATE PROCEDURE manager_schema.add_money(IN popolnenie money, IN number_of_phone character varying)
    LANGUAGE plpgsql
    AS $$begin
	if (select phone_number from subscribers_view where number_of_phone = phone_number) is null
    then raise exception 'Такого номера не зарегистрировано';
    end if;
    update subscribers_view
	set balance = balance + popolnenie 
	where phone_number = number_of_phone;
end;$$;


ALTER PROCEDURE manager_schema.add_money(IN popolnenie money, IN number_of_phone character varying) OWNER TO administrator;

--
-- TOC entry 4524 (class 0 OID 0)
-- Dependencies: 281
-- Name: PROCEDURE add_money(IN popolnenie money, IN number_of_phone character varying); Type: COMMENT; Schema: manager_schema; Owner: administrator
--

COMMENT ON PROCEDURE manager_schema.add_money(IN popolnenie money, IN number_of_phone character varying) IS 'Процедура для пополнения баланса абонентов';


--
-- TOC entry 280 (class 1255 OID 49750)
-- Name: insert_subscriber(character varying, character varying, character varying, character varying, money); Type: PROCEDURE; Schema: manager_schema; Owner: administrator
--

CREATE PROCEDURE manager_schema.insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money)
    LANGUAGE sql
    AS $$
	insert into manager_schema.subscribers_view
	(name, surname, phone_number, phone_tariff, balance) 
	values
	(subscriber_name, surname, phone_number, phone_tariff, balance);
$$;


ALTER PROCEDURE manager_schema.insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money) OWNER TO administrator;

--
-- TOC entry 4526 (class 0 OID 0)
-- Dependencies: 280
-- Name: PROCEDURE insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money); Type: COMMENT; Schema: manager_schema; Owner: administrator
--

COMMENT ON PROCEDURE manager_schema.insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money) IS 'Процедура для добавления нового абонента';


--
-- TOC entry 279 (class 1255 OID 49734)
-- Name: select_from_tariff(character varying); Type: FUNCTION; Schema: manager_schema; Owner: administrator
--

CREATE FUNCTION manager_schema.select_from_tariff(tariff_name character varying DEFAULT '%'::character varying) RETURNS TABLE(id integer, price money, phone_tariff character varying)
    LANGUAGE plpgsql
    AS $$
	begin
		return query select tariff_view.id, tariff_view.price, tariff_view.phone_tariff from tariff_view
		where tariff_view.phone_tariff ILIKE '%'||tariff_name||'%';
	end;
$$;


ALTER FUNCTION manager_schema.select_from_tariff(tariff_name character varying) OWNER TO administrator;

--
-- TOC entry 4528 (class 0 OID 0)
-- Dependencies: 279
-- Name: FUNCTION select_from_tariff(tariff_name character varying); Type: COMMENT; Schema: manager_schema; Owner: administrator
--

COMMENT ON FUNCTION manager_schema.select_from_tariff(tariff_name character varying) IS 'Функция для поиска тарифов по названию';


--
-- TOC entry 288 (class 1255 OID 50026)
-- Name: insert_call_list(character varying, character varying, date, time without time zone, interval); Type: PROCEDURE; Schema: phone_station_schema; Owner: administrator
--

CREATE PROCEDURE phone_station_schema.insert_call_list(IN outgoing_phone_number character varying, IN incoming_phone_number character varying, IN call_date date, IN call_time time without time zone, IN call_interval interval)
    LANGUAGE sql
    AS $$
	insert into call_list_view(outgoing_phone_number, incoming_phone_number, call_date, call_time, call_interval) values
	(outgoing_phone_number, incoming_phone_number, call_date, call_time, call_interval)
$$;


ALTER PROCEDURE phone_station_schema.insert_call_list(IN outgoing_phone_number character varying, IN incoming_phone_number character varying, IN call_date date, IN call_time time without time zone, IN call_interval interval) OWNER TO administrator;

--
-- TOC entry 4530 (class 0 OID 0)
-- Dependencies: 288
-- Name: PROCEDURE insert_call_list(IN outgoing_phone_number character varying, IN incoming_phone_number character varying, IN call_date date, IN call_time time without time zone, IN call_interval interval); Type: COMMENT; Schema: phone_station_schema; Owner: administrator
--

COMMENT ON PROCEDURE phone_station_schema.insert_call_list(IN outgoing_phone_number character varying, IN incoming_phone_number character varying, IN call_date date, IN call_time time without time zone, IN call_interval interval) IS 'Телефонная станция пользуется этой процедурой для добавления информации по звонкам в историю звонков (call_list), списание денежных средств производится автоматически триггерой функцией call_pay()';


--
-- TOC entry 282 (class 1255 OID 49810)
-- Name: select_minutes_to_call_from_subscribers(character varying); Type: FUNCTION; Schema: phone_station_schema; Owner: administrator
--

CREATE FUNCTION phone_station_schema.select_minutes_to_call_from_subscribers(number_of_phone character varying) RETURNS interval
    LANGUAGE plpgsql
    AS $$
	begin
	return (select to_char(minutes_to_call, 'HH24:MI:SS') from subscribers_view 
	where subscribers_view.phone_number = number_of_phone);
	end;
$$;


ALTER FUNCTION phone_station_schema.select_minutes_to_call_from_subscribers(number_of_phone character varying) OWNER TO administrator;

--
-- TOC entry 4532 (class 0 OID 0)
-- Dependencies: 282
-- Name: FUNCTION select_minutes_to_call_from_subscribers(number_of_phone character varying); Type: COMMENT; Schema: phone_station_schema; Owner: administrator
--

COMMENT ON FUNCTION phone_station_schema.select_minutes_to_call_from_subscribers(number_of_phone character varying) IS 'Запрос доступа количества минут';


--
-- TOC entry 1334 (class 1255 OID 63651)
-- Name: select_call_list(date, date, character varying); Type: FUNCTION; Schema: subscriber_schema; Owner: administrator
--

CREATE FUNCTION subscriber_schema.select_call_list(first_date date, second_date date, number_of_phone character varying) RETURNS TABLE(id integer, outgoing_phone_number character varying, call_date date, call_time time without time zone, call_interval interval, incoming_phone_number character varying)
    LANGUAGE plpgsql
    AS $$
	begin
		return query select * from subscriber_schema.call_list_view where 
		call_list_view.outgoing_phone_number = number_of_phone and
        subscriber_schema.call_list_view.call_date > first_date and
        subscriber_schema.call_list_view.call_date < second_date 
         or
        call_list_view.incoming_phone_number = number_of_phone and
        subscriber_schema.call_list_view.call_date > first_date and
        subscriber_schema.call_list_view.call_date < second_date;
	end;
$$;


ALTER FUNCTION subscriber_schema.select_call_list(first_date date, second_date date, number_of_phone character varying) OWNER TO administrator;

--
-- TOC entry 4534 (class 0 OID 0)
-- Dependencies: 1334
-- Name: FUNCTION select_call_list(first_date date, second_date date, number_of_phone character varying); Type: COMMENT; Schema: subscriber_schema; Owner: administrator
--

COMMENT ON FUNCTION subscriber_schema.select_call_list(first_date date, second_date date, number_of_phone character varying) IS 'Функция для вывода данных о звонках, в определенный период';


--
-- TOC entry 289 (class 1255 OID 50035)
-- Name: transfer_money(character varying, character varying, money); Type: PROCEDURE; Schema: subscriber_schema; Owner: administrator
--

CREATE PROCEDURE subscriber_schema.transfer_money(IN tr_out character varying, IN tr_in character varying, IN summa money)
    LANGUAGE sql
    AS $$
		insert into transfer_money_view (transfer_out, transfer_in, summ) values
		(tr_out, tr_in, summa);
$$;


ALTER PROCEDURE subscriber_schema.transfer_money(IN tr_out character varying, IN tr_in character varying, IN summa money) OWNER TO administrator;

--
-- TOC entry 4536 (class 0 OID 0)
-- Dependencies: 289
-- Name: PROCEDURE transfer_money(IN tr_out character varying, IN tr_in character varying, IN summa money); Type: COMMENT; Schema: subscriber_schema; Owner: administrator
--

COMMENT ON PROCEDURE subscriber_schema.transfer_money(IN tr_out character varying, IN tr_in character varying, IN summa money) IS 'Процедура перевода денег между абонентами, добавляет строку в таблицу transfer_money и автоматически переводит деньги после всех проверок с помощью триггерных функции transfer_money_first и transfer_money_second.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 221 (class 1259 OID 49701)
-- Name: call_list; Type: TABLE; Schema: administrator_schema; Owner: administrator
--

CREATE TABLE administrator_schema.call_list (
    id integer NOT NULL,
    outgoing_phone_number character varying(16),
    call_date date,
    call_time time without time zone,
    call_interval interval,
    incoming_phone_number character varying(16)
);


ALTER TABLE administrator_schema.call_list OWNER TO administrator;

--
-- TOC entry 4538 (class 0 OID 0)
-- Dependencies: 221
-- Name: TABLE call_list; Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON TABLE administrator_schema.call_list IS 'Список звонков всех пользователей';


--
-- TOC entry 220 (class 1259 OID 49700)
-- Name: call_list_id_seq; Type: SEQUENCE; Schema: administrator_schema; Owner: administrator
--

CREATE SEQUENCE administrator_schema.call_list_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE administrator_schema.call_list_id_seq OWNER TO administrator;

--
-- TOC entry 4539 (class 0 OID 0)
-- Dependencies: 220
-- Name: call_list_id_seq; Type: SEQUENCE OWNED BY; Schema: administrator_schema; Owner: administrator
--

ALTER SEQUENCE administrator_schema.call_list_id_seq OWNED BY administrator_schema.call_list.id;


--
-- TOC entry 217 (class 1259 OID 49680)
-- Name: subscribers; Type: TABLE; Schema: administrator_schema; Owner: administrator
--

CREATE TABLE administrator_schema.subscribers (
    id integer NOT NULL,
    name character varying(20),
    surname character varying(20),
    phone_number character varying(16),
    balance money,
    phone_tariff character varying(16),
    minutes_to_call interval,
    login character varying(32)
);


ALTER TABLE administrator_schema.subscribers OWNER TO administrator;

--
-- TOC entry 216 (class 1259 OID 49679)
-- Name: subscribers_id_seq; Type: SEQUENCE; Schema: administrator_schema; Owner: administrator
--

CREATE SEQUENCE administrator_schema.subscribers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE administrator_schema.subscribers_id_seq OWNER TO administrator;

--
-- TOC entry 4541 (class 0 OID 0)
-- Dependencies: 216
-- Name: subscribers_id_seq; Type: SEQUENCE OWNED BY; Schema: administrator_schema; Owner: administrator
--

ALTER SEQUENCE administrator_schema.subscribers_id_seq OWNED BY administrator_schema.subscribers.id;


--
-- TOC entry 219 (class 1259 OID 49687)
-- Name: tariff; Type: TABLE; Schema: administrator_schema; Owner: administrator
--

CREATE TABLE administrator_schema.tariff (
    id integer NOT NULL,
    price money,
    phone_tariff character varying(16)
);


ALTER TABLE administrator_schema.tariff OWNER TO administrator;

--
-- TOC entry 4543 (class 0 OID 0)
-- Dependencies: 219
-- Name: TABLE tariff; Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON TABLE administrator_schema.tariff IS 'Список тарифов';


--
-- TOC entry 218 (class 1259 OID 49686)
-- Name: tariff_id_seq; Type: SEQUENCE; Schema: administrator_schema; Owner: administrator
--

CREATE SEQUENCE administrator_schema.tariff_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE administrator_schema.tariff_id_seq OWNER TO administrator;

--
-- TOC entry 4544 (class 0 OID 0)
-- Dependencies: 218
-- Name: tariff_id_seq; Type: SEQUENCE OWNED BY; Schema: administrator_schema; Owner: administrator
--

ALTER SEQUENCE administrator_schema.tariff_id_seq OWNED BY administrator_schema.tariff.id;


--
-- TOC entry 228 (class 1259 OID 50001)
-- Name: transfer_money; Type: TABLE; Schema: administrator_schema; Owner: administrator
--

CREATE TABLE administrator_schema.transfer_money (
    id integer NOT NULL,
    transfer_out character varying(16),
    transfer_in character varying(16),
    summ money
);


ALTER TABLE administrator_schema.transfer_money OWNER TO administrator;

--
-- TOC entry 4545 (class 0 OID 0)
-- Dependencies: 228
-- Name: TABLE transfer_money; Type: COMMENT; Schema: administrator_schema; Owner: administrator
--

COMMENT ON TABLE administrator_schema.transfer_money IS 'Таблица для регистрации переводов со счета на счет, при добавлении строк в таблицу автоматически переводит деньги, см триггерные функции transfer_money_first() и transfer_money_second()';


--
-- TOC entry 227 (class 1259 OID 50000)
-- Name: transfer_money_id_seq; Type: SEQUENCE; Schema: administrator_schema; Owner: administrator
--

CREATE SEQUENCE administrator_schema.transfer_money_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE administrator_schema.transfer_money_id_seq OWNER TO administrator;

--
-- TOC entry 4546 (class 0 OID 0)
-- Dependencies: 227
-- Name: transfer_money_id_seq; Type: SEQUENCE OWNED BY; Schema: administrator_schema; Owner: administrator
--

ALTER SEQUENCE administrator_schema.transfer_money_id_seq OWNED BY administrator_schema.transfer_money.id;


--
-- TOC entry 223 (class 1259 OID 49746)
-- Name: subscribers_view; Type: VIEW; Schema: manager_schema; Owner: administrator
--

CREATE VIEW manager_schema.subscribers_view AS
 SELECT subscribers.id,
    subscribers.name,
    subscribers.surname,
    subscribers.phone_number,
    subscribers.balance,
    subscribers.phone_tariff,
    subscribers.minutes_to_call
   FROM administrator_schema.subscribers;


ALTER TABLE manager_schema.subscribers_view OWNER TO administrator;

--
-- TOC entry 222 (class 1259 OID 49736)
-- Name: tariff_view; Type: VIEW; Schema: manager_schema; Owner: administrator
--

CREATE VIEW manager_schema.tariff_view AS
 SELECT tariff.id,
    tariff.price,
    tariff.phone_tariff
   FROM administrator_schema.tariff;


ALTER TABLE manager_schema.tariff_view OWNER TO administrator;

--
-- TOC entry 230 (class 1259 OID 50022)
-- Name: call_list_view; Type: VIEW; Schema: phone_station_schema; Owner: administrator
--

CREATE VIEW phone_station_schema.call_list_view AS
 SELECT call_list.id,
    call_list.outgoing_phone_number,
    call_list.call_date,
    call_list.call_time,
    call_list.call_interval,
    call_list.incoming_phone_number
   FROM administrator_schema.call_list;


ALTER TABLE phone_station_schema.call_list_view OWNER TO administrator;

--
-- TOC entry 224 (class 1259 OID 49791)
-- Name: subscribers_view; Type: VIEW; Schema: phone_station_schema; Owner: administrator
--

CREATE VIEW phone_station_schema.subscribers_view AS
 SELECT subscribers.id,
    subscribers.name,
    subscribers.surname,
    subscribers.phone_number,
    subscribers.balance,
    subscribers.phone_tariff,
    subscribers.minutes_to_call
   FROM administrator_schema.subscribers;


ALTER TABLE phone_station_schema.subscribers_view OWNER TO administrator;

--
-- TOC entry 225 (class 1259 OID 49815)
-- Name: tariff_view; Type: VIEW; Schema: phone_station_schema; Owner: administrator
--

CREATE VIEW phone_station_schema.tariff_view AS
 SELECT tariff.id,
    tariff.price,
    tariff.phone_tariff
   FROM administrator_schema.tariff;


ALTER TABLE phone_station_schema.tariff_view OWNER TO administrator;

--
-- TOC entry 236 (class 1259 OID 63497)
-- Name: call_list_view; Type: VIEW; Schema: subscriber_schema; Owner: administrator
--

CREATE VIEW subscriber_schema.call_list_view AS
 SELECT call_list.id,
    call_list.outgoing_phone_number,
    call_list.call_date,
    call_list.call_time,
    call_list.call_interval,
    call_list.incoming_phone_number
   FROM administrator_schema.call_list
  WHERE (((call_list.outgoing_phone_number)::text IN ( SELECT subscribers.phone_number
           FROM administrator_schema.subscribers
          WHERE ((subscribers.login)::text = CURRENT_USER))) OR ((call_list.incoming_phone_number)::text IN ( SELECT subscribers.phone_number
           FROM administrator_schema.subscribers
          WHERE ((subscribers.login)::text = CURRENT_USER))));


ALTER TABLE subscriber_schema.call_list_view OWNER TO administrator;

--
-- TOC entry 226 (class 1259 OID 49996)
-- Name: subscribers_view; Type: VIEW; Schema: subscriber_schema; Owner: administrator
--

CREATE VIEW subscriber_schema.subscribers_view AS
 SELECT subscribers.id,
    subscribers.name,
    subscribers.surname,
    subscribers.phone_number,
    subscribers.balance,
    subscribers.phone_tariff,
    subscribers.minutes_to_call,
    subscribers.login
   FROM administrator_schema.subscribers
  WHERE ((subscribers.login)::text = CURRENT_USER);


ALTER TABLE subscriber_schema.subscribers_view OWNER TO administrator;

--
-- TOC entry 4554 (class 0 OID 0)
-- Dependencies: 226
-- Name: VIEW subscribers_view; Type: COMMENT; Schema: subscriber_schema; Owner: administrator
--

COMMENT ON VIEW subscriber_schema.subscribers_view IS 'Возвращает из  subscribers только строки к номерам телефонов которых у подключенного пользователя есть доступ.';


--
-- TOC entry 229 (class 1259 OID 50009)
-- Name: transfer_money_view; Type: VIEW; Schema: subscriber_schema; Owner: administrator
--

CREATE VIEW subscriber_schema.transfer_money_view AS
 SELECT transfer_money.id,
    transfer_money.transfer_out,
    transfer_money.transfer_in,
    transfer_money.summ
   FROM administrator_schema.transfer_money;


ALTER TABLE subscriber_schema.transfer_money_view OWNER TO administrator;

--
-- TOC entry 235 (class 1259 OID 53613)
-- Name: test; Type: TABLE; Schema: tap; Owner: superuser
--

CREATE TABLE tap.test (
    id integer NOT NULL
);


ALTER TABLE tap.test OWNER TO superuser;

--
-- TOC entry 234 (class 1259 OID 53612)
-- Name: test_id_seq; Type: SEQUENCE; Schema: tap; Owner: superuser
--

CREATE SEQUENCE tap.test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tap.test_id_seq OWNER TO superuser;

--
-- TOC entry 4557 (class 0 OID 0)
-- Dependencies: 234
-- Name: test_id_seq; Type: SEQUENCE OWNED BY; Schema: tap; Owner: superuser
--

ALTER SEQUENCE tap.test_id_seq OWNED BY tap.test.id;


--
-- TOC entry 4324 (class 2604 OID 49704)
-- Name: call_list id; Type: DEFAULT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.call_list ALTER COLUMN id SET DEFAULT nextval('administrator_schema.call_list_id_seq'::regclass);


--
-- TOC entry 4322 (class 2604 OID 49683)
-- Name: subscribers id; Type: DEFAULT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.subscribers ALTER COLUMN id SET DEFAULT nextval('administrator_schema.subscribers_id_seq'::regclass);


--
-- TOC entry 4323 (class 2604 OID 49690)
-- Name: tariff id; Type: DEFAULT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.tariff ALTER COLUMN id SET DEFAULT nextval('administrator_schema.tariff_id_seq'::regclass);


--
-- TOC entry 4325 (class 2604 OID 50004)
-- Name: transfer_money id; Type: DEFAULT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.transfer_money ALTER COLUMN id SET DEFAULT nextval('administrator_schema.transfer_money_id_seq'::regclass);


--
-- TOC entry 4326 (class 2604 OID 53616)
-- Name: test id; Type: DEFAULT; Schema: tap; Owner: superuser
--

ALTER TABLE ONLY tap.test ALTER COLUMN id SET DEFAULT nextval('tap.test_id_seq'::regclass);


--
-- TOC entry 4503 (class 0 OID 49701)
-- Dependencies: 221
-- Data for Name: call_list; Type: TABLE DATA; Schema: administrator_schema; Owner: administrator
--



--
-- TOC entry 4499 (class 0 OID 49680)
-- Dependencies: 217
-- Data for Name: subscribers; Type: TABLE DATA; Schema: administrator_schema; Owner: administrator
--



--
-- TOC entry 4501 (class 0 OID 49687)
-- Dependencies: 219
-- Data for Name: tariff; Type: TABLE DATA; Schema: administrator_schema; Owner: administrator
--



--
-- TOC entry 4505 (class 0 OID 50001)
-- Dependencies: 228
-- Data for Name: transfer_money; Type: TABLE DATA; Schema: administrator_schema; Owner: administrator
--



--
-- TOC entry 4507 (class 0 OID 53613)
-- Dependencies: 235
-- Data for Name: test; Type: TABLE DATA; Schema: tap; Owner: superuser
--



--
-- TOC entry 4558 (class 0 OID 0)
-- Dependencies: 220
-- Name: call_list_id_seq; Type: SEQUENCE SET; Schema: administrator_schema; Owner: administrator
--

SELECT pg_catalog.setval('administrator_schema.call_list_id_seq', 8, true);


--
-- TOC entry 4559 (class 0 OID 0)
-- Dependencies: 216
-- Name: subscribers_id_seq; Type: SEQUENCE SET; Schema: administrator_schema; Owner: administrator
--

SELECT pg_catalog.setval('administrator_schema.subscribers_id_seq', 22, true);


--
-- TOC entry 4560 (class 0 OID 0)
-- Dependencies: 218
-- Name: tariff_id_seq; Type: SEQUENCE SET; Schema: administrator_schema; Owner: administrator
--

SELECT pg_catalog.setval('administrator_schema.tariff_id_seq', 215, true);


--
-- TOC entry 4561 (class 0 OID 0)
-- Dependencies: 227
-- Name: transfer_money_id_seq; Type: SEQUENCE SET; Schema: administrator_schema; Owner: administrator
--

SELECT pg_catalog.setval('administrator_schema.transfer_money_id_seq', 5, true);


--
-- TOC entry 4562 (class 0 OID 0)
-- Dependencies: 234
-- Name: test_id_seq; Type: SEQUENCE SET; Schema: tap; Owner: superuser
--

SELECT pg_catalog.setval('tap.test_id_seq', 1, false);


--
-- TOC entry 4337 (class 2606 OID 49706)
-- Name: call_list call_list_pkey; Type: CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.call_list
    ADD CONSTRAINT call_list_pkey PRIMARY KEY (id);


--
-- TOC entry 4329 (class 2606 OID 49767)
-- Name: subscribers subscribers_phone_number_key; Type: CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.subscribers
    ADD CONSTRAINT subscribers_phone_number_key UNIQUE (phone_number);


--
-- TOC entry 4331 (class 2606 OID 49685)
-- Name: subscribers subscribers_pkey; Type: CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.subscribers
    ADD CONSTRAINT subscribers_pkey PRIMARY KEY (id);


--
-- TOC entry 4333 (class 2606 OID 49694)
-- Name: tariff tariff_phone_tariff_key; Type: CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.tariff
    ADD CONSTRAINT tariff_phone_tariff_key UNIQUE (phone_tariff);


--
-- TOC entry 4335 (class 2606 OID 49692)
-- Name: tariff tariff_pkey; Type: CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.tariff
    ADD CONSTRAINT tariff_pkey PRIMARY KEY (id);


--
-- TOC entry 4340 (class 2606 OID 50006)
-- Name: transfer_money transfer_money_pkey; Type: CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.transfer_money
    ADD CONSTRAINT transfer_money_pkey PRIMARY KEY (id);


--
-- TOC entry 4342 (class 2606 OID 53618)
-- Name: test test_pkey; Type: CONSTRAINT; Schema: tap; Owner: superuser
--

ALTER TABLE ONLY tap.test
    ADD CONSTRAINT test_pkey PRIMARY KEY (id);


--
-- TOC entry 4338 (class 1259 OID 67168)
-- Name: idx_outgoing_phone_number; Type: INDEX; Schema: administrator_schema; Owner: administrator
--

CREATE INDEX idx_outgoing_phone_number ON administrator_schema.call_list USING btree (outgoing_phone_number);


--
-- TOC entry 4327 (class 1259 OID 67169)
-- Name: idx_phone_number; Type: INDEX; Schema: administrator_schema; Owner: administrator
--

CREATE INDEX idx_phone_number ON administrator_schema.subscribers USING btree (phone_number);


--
-- TOC entry 4344 (class 2620 OID 49789)
-- Name: subscribers add_money; Type: TRIGGER; Schema: administrator_schema; Owner: administrator
--

CREATE TRIGGER add_money BEFORE INSERT OR UPDATE ON administrator_schema.subscribers FOR EACH ROW EXECUTE FUNCTION administrator_schema.refresh_minutes();


--
-- TOC entry 4345 (class 2620 OID 50033)
-- Name: call_list call_pay; Type: TRIGGER; Schema: administrator_schema; Owner: administrator
--

CREATE TRIGGER call_pay BEFORE INSERT ON administrator_schema.call_list FOR EACH ROW EXECUTE FUNCTION administrator_schema.call_pay();


--
-- TOC entry 4347 (class 2620 OID 50017)
-- Name: transfer_money transfer_money_first; Type: TRIGGER; Schema: administrator_schema; Owner: administrator
--

CREATE TRIGGER transfer_money_first BEFORE INSERT ON administrator_schema.transfer_money FOR EACH ROW EXECUTE FUNCTION administrator_schema.transfer_money_first();


--
-- TOC entry 4346 (class 2620 OID 50018)
-- Name: transfer_money transfer_money_second; Type: TRIGGER; Schema: administrator_schema; Owner: administrator
--

CREATE TRIGGER transfer_money_second AFTER INSERT ON administrator_schema.transfer_money FOR EACH ROW EXECUTE FUNCTION administrator_schema.transfer_money_second();


--
-- TOC entry 4343 (class 2606 OID 49695)
-- Name: subscribers tariff_reference; Type: FK CONSTRAINT; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE ONLY administrator_schema.subscribers
    ADD CONSTRAINT tariff_reference FOREIGN KEY (phone_tariff) REFERENCES administrator_schema.tariff(phone_tariff) NOT VALID;


--
-- TOC entry 4497 (class 0 OID 49701)
-- Dependencies: 221
-- Name: call_list; Type: ROW SECURITY; Schema: administrator_schema; Owner: administrator
--

ALTER TABLE administrator_schema.call_list ENABLE ROW LEVEL SECURITY;

--
-- TOC entry 4513 (class 0 OID 0)
-- Dependencies: 6
-- Name: SCHEMA manager_schema; Type: ACL; Schema: -; Owner: administrator
--

GRANT USAGE ON SCHEMA manager_schema TO manager;


--
-- TOC entry 4514 (class 0 OID 0)
-- Dependencies: 7
-- Name: SCHEMA phone_station_schema; Type: ACL; Schema: -; Owner: administrator
--

GRANT USAGE ON SCHEMA phone_station_schema TO phone_station;


--
-- TOC entry 4515 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA subscriber_schema; Type: ACL; Schema: -; Owner: administrator
--

GRANT USAGE ON SCHEMA subscriber_schema TO subscribers;


--
-- TOC entry 4519 (class 0 OID 0)
-- Dependencies: 283
-- Name: FUNCTION refresh_minutes(); Type: ACL; Schema: administrator_schema; Owner: administrator
--

REVOKE ALL ON FUNCTION administrator_schema.refresh_minutes() FROM PUBLIC;


--
-- TOC entry 4521 (class 0 OID 0)
-- Dependencies: 286
-- Name: FUNCTION transfer_money_first(); Type: ACL; Schema: administrator_schema; Owner: administrator
--

REVOKE ALL ON FUNCTION administrator_schema.transfer_money_first() FROM PUBLIC;
GRANT ALL ON FUNCTION administrator_schema.transfer_money_first() TO subscribers;


--
-- TOC entry 4523 (class 0 OID 0)
-- Dependencies: 285
-- Name: FUNCTION transfer_money_second(); Type: ACL; Schema: administrator_schema; Owner: administrator
--

REVOKE ALL ON FUNCTION administrator_schema.transfer_money_second() FROM PUBLIC;
GRANT ALL ON FUNCTION administrator_schema.transfer_money_second() TO subscribers;


--
-- TOC entry 4525 (class 0 OID 0)
-- Dependencies: 281
-- Name: PROCEDURE add_money(IN popolnenie money, IN number_of_phone character varying); Type: ACL; Schema: manager_schema; Owner: administrator
--

GRANT ALL ON PROCEDURE manager_schema.add_money(IN popolnenie money, IN number_of_phone character varying) TO manager;


--
-- TOC entry 4527 (class 0 OID 0)
-- Dependencies: 280
-- Name: PROCEDURE insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money); Type: ACL; Schema: manager_schema; Owner: administrator
--

REVOKE ALL ON PROCEDURE manager_schema.insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money) FROM PUBLIC;
GRANT ALL ON PROCEDURE manager_schema.insert_subscriber(IN subscriber_name character varying, IN surname character varying, IN phone_number character varying, IN phone_tariff character varying, IN balance money) TO manager;


--
-- TOC entry 4529 (class 0 OID 0)
-- Dependencies: 279
-- Name: FUNCTION select_from_tariff(tariff_name character varying); Type: ACL; Schema: manager_schema; Owner: administrator
--

REVOKE ALL ON FUNCTION manager_schema.select_from_tariff(tariff_name character varying) FROM PUBLIC;
GRANT ALL ON FUNCTION manager_schema.select_from_tariff(tariff_name character varying) TO manager;


--
-- TOC entry 4531 (class 0 OID 0)
-- Dependencies: 288
-- Name: PROCEDURE insert_call_list(IN outgoing_phone_number character varying, IN incoming_phone_number character varying, IN call_date date, IN call_time time without time zone, IN call_interval interval); Type: ACL; Schema: phone_station_schema; Owner: administrator
--

GRANT ALL ON PROCEDURE phone_station_schema.insert_call_list(IN outgoing_phone_number character varying, IN incoming_phone_number character varying, IN call_date date, IN call_time time without time zone, IN call_interval interval) TO phone_station;


--
-- TOC entry 4533 (class 0 OID 0)
-- Dependencies: 282
-- Name: FUNCTION select_minutes_to_call_from_subscribers(number_of_phone character varying); Type: ACL; Schema: phone_station_schema; Owner: administrator
--

GRANT ALL ON FUNCTION phone_station_schema.select_minutes_to_call_from_subscribers(number_of_phone character varying) TO phone_station;


--
-- TOC entry 4535 (class 0 OID 0)
-- Dependencies: 1334
-- Name: FUNCTION select_call_list(first_date date, second_date date, number_of_phone character varying); Type: ACL; Schema: subscriber_schema; Owner: administrator
--

GRANT ALL ON FUNCTION subscriber_schema.select_call_list(first_date date, second_date date, number_of_phone character varying) TO subscribers;


--
-- TOC entry 4537 (class 0 OID 0)
-- Dependencies: 289
-- Name: PROCEDURE transfer_money(IN tr_out character varying, IN tr_in character varying, IN summa money); Type: ACL; Schema: subscriber_schema; Owner: administrator
--

GRANT ALL ON PROCEDURE subscriber_schema.transfer_money(IN tr_out character varying, IN tr_in character varying, IN summa money) TO subscribers;


--
-- TOC entry 4540 (class 0 OID 0)
-- Dependencies: 220
-- Name: SEQUENCE call_list_id_seq; Type: ACL; Schema: administrator_schema; Owner: administrator
--

GRANT ALL ON SEQUENCE administrator_schema.call_list_id_seq TO phone_station;


--
-- TOC entry 4542 (class 0 OID 0)
-- Dependencies: 216
-- Name: SEQUENCE subscribers_id_seq; Type: ACL; Schema: administrator_schema; Owner: administrator
--

GRANT ALL ON SEQUENCE administrator_schema.subscribers_id_seq TO manager;


--
-- TOC entry 4547 (class 0 OID 0)
-- Dependencies: 227
-- Name: SEQUENCE transfer_money_id_seq; Type: ACL; Schema: administrator_schema; Owner: administrator
--

GRANT SELECT,USAGE ON SEQUENCE administrator_schema.transfer_money_id_seq TO subscribers;


--
-- TOC entry 4548 (class 0 OID 0)
-- Dependencies: 223
-- Name: TABLE subscribers_view; Type: ACL; Schema: manager_schema; Owner: administrator
--

GRANT SELECT,INSERT,UPDATE ON TABLE manager_schema.subscribers_view TO manager;


--
-- TOC entry 4549 (class 0 OID 0)
-- Dependencies: 222
-- Name: TABLE tariff_view; Type: ACL; Schema: manager_schema; Owner: administrator
--

GRANT SELECT ON TABLE manager_schema.tariff_view TO manager;


--
-- TOC entry 4550 (class 0 OID 0)
-- Dependencies: 230
-- Name: TABLE call_list_view; Type: ACL; Schema: phone_station_schema; Owner: administrator
--

GRANT SELECT,INSERT ON TABLE phone_station_schema.call_list_view TO phone_station;


--
-- TOC entry 4551 (class 0 OID 0)
-- Dependencies: 224
-- Name: TABLE subscribers_view; Type: ACL; Schema: phone_station_schema; Owner: administrator
--

GRANT SELECT,UPDATE ON TABLE phone_station_schema.subscribers_view TO phone_station;


--
-- TOC entry 4552 (class 0 OID 0)
-- Dependencies: 225
-- Name: TABLE tariff_view; Type: ACL; Schema: phone_station_schema; Owner: administrator
--

GRANT SELECT ON TABLE phone_station_schema.tariff_view TO phone_station;


--
-- TOC entry 4553 (class 0 OID 0)
-- Dependencies: 236
-- Name: TABLE call_list_view; Type: ACL; Schema: subscriber_schema; Owner: administrator
--

GRANT SELECT ON TABLE subscriber_schema.call_list_view TO subscribers;


--
-- TOC entry 4555 (class 0 OID 0)
-- Dependencies: 226
-- Name: TABLE subscribers_view; Type: ACL; Schema: subscriber_schema; Owner: administrator
--

GRANT SELECT ON TABLE subscriber_schema.subscribers_view TO subscribers;


--
-- TOC entry 4556 (class 0 OID 0)
-- Dependencies: 229
-- Name: TABLE transfer_money_view; Type: ACL; Schema: subscriber_schema; Owner: administrator
--

GRANT INSERT ON TABLE subscriber_schema.transfer_money_view TO subscribers;


-- Completed on 2022-08-02 16:11:01

--
-- PostgreSQL database dump complete
--

