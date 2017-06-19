---
layout: post
title: 'Common Table Expressions in ActiveRecord: A Case Study of Quantiles'
date: 2017-06-05
tags:
  - ruby
  - rails
  - activerecord
  - arel
  - postgresql
  - common table expressions
  - window functions
---

## Framing

Today, we are going to look at a straightforward real-world problem, and build a
comprehensive solution.  In doing so, we will start with some various naive
approaches as we increase our understanding of the underlying mechanics,
encounter some pitfalls, and, ultimately, approach a reasonable level of
sophistication and abstraction.  The stack we will be using for this case study
is
{% fancylink %}
  http://rubyonrails.org/
  Ruby on Rails 5.1
{% endfancylink %}
with
{% fancylink %}
  https://www.postgresql.org/
  PostgreSQL 9.6
{% endfancylink %}
for the database.

Now, let me present to you the problem through which we will frame this
discussion:  given a number of student records, when displaying a single
student, also display the quintile into which their grade falls.

##

# Calculating Quantiles in PostgreSQL

Let us begin by looking at the structure of our `students` table.  The
following was generated with a simple Rails migration, the details of which are
outside the scope of this article.  The table, intentionally simple for the
purpose of illustration, only has columns for an `id`, a `name`, and a `grade`.

{% highlight psql %}
# \d students
                              Table "public.students"
 Column |       Type        |                       Modifiers
--------+-------------------+-------------------------------------------------------
 id     | bigint            | not null default nextval('students_id_seq'::regclass)
 name   | character varying | not null
 grade  | integer           | not null
Indexes:
    "students_pkey" PRIMARY KEY, btree (id)
{% endhighlight %}

In order to have some data to work with, we want to generate some at random.  We
use the following command to create a million records with grades between 0 and
100.  As you can see from the subsequent queries, we now have a corpus upon
which to operate.  Since we are working with a million rows, we know each
quintile contains 200,000 records, and we can safely assume that they will be
split fairly close to multiples of 20.  We will soon be able to confirm this
assumption.

{% highlight psql %}
# insert into students (name, grade)
select
  left(md5(i::text), 10),
  (random()*100)::int
from generate_series(1, 1000000) s(i);
INSERT 0 1000000
{% endhighlight %}

{% highlight psql %}
# select count(*) from students;
  count
  ---------
   1000000
   (1 row)
{% endhighlight %}

{% highlight psql %}
# select * from students limit 10;
 id |    name    | grade
----+------------+-------
  1 | c4ca4238a0 |    29
  2 | c81e728d9d |    87
  3 | eccbc87e4b |    26
  4 | a87ff679a2 |    43
  5 | e4da3b7fbb |    59
  6 | 1679091c5a |    44
  7 | 8f14e45fce |    53
  8 | c9f0f895fb |     4
  9 | 45c48cce2e |    81
 10 | d3d9446802 |    12
(10 rows)
{% endhighlight %}

In order to calculate quantiles, we will be making use of a PostgreSQL feature
called
{% fancylink %}
  https://www.postgresql.org/docs/9.6/static/tutorial-window.html
  window functions
{% endfancylink %}.
Using the
{% fancylink %}
  https://www.postgresql.org/docs/9.6/static/functions-window.html
  `ntile()`
{% endfancylink %}
function, it is actually fairly trivial to calculate the quintile for a row.  As
can be seen in the following query, this is the case so long as we use a `limit`
clause to only return one row. Using the
{% fancylink %}
  https://www.postgresql.org/docs/9.6/static/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS
  window function call syntax
{% endfancylink %}, we define a computed column `quintile` using `ntile(5)` over
the grade column, ordered.

{% highlight psql %}
# select *, ntile(5) over (order by grade) as quintile from students order by id limit 1;
  id |    name    | grade | quintile
 ----+------------+-------+----------
   1 | c4ca4238a0 |    29 |        2
   (1 row)
{% endhighlight %}

But something interesting happens when we try to use a `where` clause to get the
same result:  we get a different, incorrect, result.  This is because window
functions operate over the set of records returned by the `from/where` clause,
so, in this next case, only sees one record.  This makes our current query
useless, since we are under the constraint of needing to display the quintile
for a specific record.

At this point, it would also be nice to confirm that our data has the expected
shape, but we run into another interesting limitation: namely, that we cannot
use window functions inside the `group by` clause.

{% highlight psql %}
# select *, ntile(5) over (order by grade) as quintile from students where id = 1;
 id |    name    | grade | quintile
----+------------+-------+----------
  1 | c4ca4238a0 |    29 |        1
(1 row)
{% endhighlight %}

{% highlight psql %}
# select count(*), ntile(5) over (order by grade) as quintile from students group by quintile;
ERROR:  window functions are not allowed in GROUP BY
LINE 1: select count(*), ntile(5) over (order by grade) as quintile ...
                         ^
{% endhighlight %}

Luckily, SQL queries, generally speaking, can often be reshaped into a form that
is sufficient for our needs.  In particular, we can use another feature of
PostgreSQL to work around these early teething problems:
{% fancylink %}
  https://www.postgresql.org/docs/9.6/static/queries-with.html
  common table expressions, aka `with` queries
{% endfancylink %}.

Using a common table expression, we generate a temporary table for the duration
of this query.  This table will contain our quintile value, and we will pull the
data from it.  For now, we will just call it `quintile_table`.  As an aside, it
is worthwhile to note that common table expressions are also capable of
significantly more advanced features, including iteration (albeit invoked using
the `recursive` keyword), but we need not concern ourselves with those details
here.

{% highlight psql %}
# with quintile_table as (select *, ntile(5) over (order by grade) as quintile from students)
	select * from quintile_table where id = 1;
 id |    name    | grade | quintile
----+------------+-------+----------
  1 | c4ca4238a0 |    29 |        2
(1 row)
{% endhighlight %}

That query gave us exactly the output we desire.  The current shape of the query
also conveys upon us the ability to cheat the restriction of not being able to
use window functions in a `group by` clause, since we are now grouping on a
column from the temporary table, and PostgreSQL treats this like any other
column.  As evidenced in the following query, the data looks exactly how we
expected.

{% highlight psql %}
# with quintile_table as (select *, ntile(5) over (order by grade) as quintile from students)
	select count(*), min(grade) as min, max(grade) as max, quintile
	from quintile_table group by quintile order by quintile;
 count  | min | max | quintile
--------+-----+-----+----------
 200000 |   0 |  20 |        1
 200000 |  20 |  40 |        2
 200000 |  40 |  60 |        3
 200000 |  60 |  80 |        4
 200000 |  80 | 100 |        5
(5 rows)
{% endhighlight %}

The added layer of complexity, necessary to allow us to filter on an arbitrary
`where` clause should be expected to increase the computational cost of the
query, but that is actually not the case in a substantial way.  The start-up
cost for the query using common table expressions is less (by 5000) than that of
the naive query using a `limit` clause, which means the output phase should be
expected to actually begin earlier.  True, the total cost is more by 17499.99,
but that seems like a slight cost to pay in order to get the desired result
from amongst a million records.

{% highlight psql %}
# explain select *, ntile(5) over (order by grade) as quintile from students order by id limit 1;
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Limit  (cost=159037.84..159037.85 rows=1 width=27)
   ->  Sort  (cost=159037.84..161537.84 rows=1000000 width=27)
         Sort Key: id
         ->  WindowAgg  (cost=136537.84..154037.84 rows=1000000 width=27)
               ->  Sort  (cost=136537.84..139037.84 rows=1000000 width=23)
                     Sort Key: grade
                     ->  Seq Scan on students  (cost=0.00..16370.00 rows=1000000 width=23)
(7 rows)
{% endhighlight %}

{% highlight psql %}
# explain with quintile_table as (select *, ntile(5) over (order by grade) as quintile from students)
  select * from quintile_table where id = 1;
                                      QUERY PLAN
---------------------------------------------------------------------------------------
 CTE Scan on quintile_table  (cost=154037.84..176537.84 rows=5000 width=48)
   Filter: (id = 1)
   CTE quintile_table
     ->  WindowAgg  (cost=136537.84..154037.84 rows=1000000 width=27)
           ->  Sort  (cost=136537.84..139037.84 rows=1000000 width=23)
                 Sort Key: students.grade
                 ->  Seq Scan on students  (cost=0.00..16370.00 rows=1000000 width=23)
(7 rows)
{% endhighlight %}

It is worthwhile to note, before going any further, that this method would not
be sufficiently performant in a production environment for a data set of this
size; some caching or precomputation layer would be necessary, but that is
outside the scope of this article.

## Integrating into Rails

At this point, we have a query that can handle arbitrary filtering, but we want
to use it within an `ActiveRecord` model.  The first thought may be that we can
simply use
{% fancylink %}
  http://api.rubyonrails.org/classes/ActiveRecord/QueryMethods.html#method-i-select
  ActiveRecord::QueryMethods#select
{% endfancylink %},
but we are about to take a step backwards.

(N.B. We break down the long SQL string into separate clauses using an array
and joining it back into a string for the query; while this may not be the best
practice, it is a sufficient way to break up long chunks of SQL when
prototyping.)

{% highlight irb %}
>> puts Student.
?> select([
?>   'with quintile_table',
?>   'as (select *, ntile(5) over (order by grade)',
?>   'as quintile from students)'
?> ].join(' ')).
?> to_sql
SELECT with quintile_table as (select *, ntile(5) over (order by grade) as quintile from students) FROM "students"
{% endhighlight %}

The result is, again, not what we desire, and we must step back.  Actually
reading the documentation for the `select` method, we see it takes a list of
fields we wish to select, but does not overwrite the entire `select` clause, as
we (with intentional naivete) assumed.  Instead, we will have to again reshape
the query into a way that will allow for composability within the constraints of
an `ActiveRecord` model.

Thinking in terms of how we compose queries using scopes in Rails, it may be
best to define our optimal interface before going forward.  In this case, a
standalone `with_quintile` scope would be optimal, and we would want to be able
to use it just like any other scope, with its internals abstracted.  Consider
the following: `Student.with_quintile.where(id: 1).first.quintile`

In order to achieve this result, we will need to abandon our attempts to
manipulate the `select` clause to our ends and, instead, focus on the `from`
clause.  Very simply, we can alias our original `quintile_table` as `students`,
the `table_name` of our table, thereby tricking all other normal scopes into
being well behaved in its presence.  As far as they are concerned, the
`students` table has the `quintile` column there at all times.

{% highlight irb %}
>> Student.
?> from([
?>  '(with "quintile_table"',
?>  'as (select *, ntile(5) over (order by grade)',
?>  'as quintile from "students") select * from "quintile_table")',
?>  'as "students"'
?> ].join(' ')).
?> where(id: 1).
?> first.
?> quintile
  Student Load (672.7ms)  SELECT  "students".* FROM (with "quintile_table" as (select *, ntile(5) over (order by grade) as quintile from "students") select * from "quintile_table") as "students" WHERE "students"."id" = $1 ORDER BY "students"."id" ASC LIMIT $2  [["id", 1], ["LIMIT", 1]]
=> 2
{% endhighlight %}

It would, again, be reasonable to believe additional misdirection such as this
would increase the cost of the query, but the `limit` clause added by the call
to `ActiveRecord::FinderMethods#first` effectively reduces the total cost back
to the initial value.

{% highlight psql %}
# explain
  select "students".*
  from (with "quintile_table"
        as (select *, ntile(5)
        over (order by grade) as quintile
        from "students")
    select * from "quintile_table") as "students"
  where "students"."id" = 1
  order by "students"."id" asc
  limit 1;
                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 Limit  (cost=154037.84..154042.35 rows=1 width=48)
   ->  CTE Scan on quintile_table  (cost=154037.84..176537.84 rows=5000 width=48)
         Filter: (id = 1)
         CTE quintile_table
           ->  WindowAgg  (cost=136537.84..154037.84 rows=1000000 width=27)
                 ->  Sort  (cost=136537.84..139037.84 rows=1000000 width=23)
                       Sort Key: students.grade
                       ->  Seq Scan on students  (cost=0.00..16370.00 rows=1000000 width=23)
(8 rows)
{% endhighlight %}

## Achieving Modularity Using AREL

We can now say that we have gotten to a point where we can simply wrap what we
have in a scope, and call it good.  Were this a feature for a client on a time
sensitive project, I would probably agree; but we can certainly do better than
the following.

{% highlight ruby %}
class Student < ApplicationRecord
  scope :with_quintile, -> {
    from([
      '(with "quintile_table" as (select *, ntile(5)',
      'over (order by grade) as quintile from "students")',
      'select * from "quintile_table") as "students"'
    ].join(' '))
  }
end
{% endhighlight %}

Normally, it is
{% fancylink %}
  https://gist.github.com/ryanb/4172391
  considered bad practice
{% endfancylink %}
to hide complexity within modules, so the following is not inherently a
recommendation, so much as an elaboration on how we would approach generalizing
what we already have.  On the other hand, having worked on large, long-lived
projects, I cannot stress enough the maintenance issues caused by having pieces
of hard-coded SQL strewn within model classes.  As such, the conversion to use
{% fancylink %}
  https://github.com/rails/arel
  AREL
{% endfancylink %}
is an explicit recommendation.

Here, we create a new `ActiveSupport::Concern` module in
`app/models/concerns/quintile.rb`, which we will include in any class we want
to be able to call our scope on.  In this case, we have removed any explicit to
both the table name or the column we are using as our calculation.
Consequently, this module can already be included any `ActiveRecord` model,
its `quintile_on` class macro used, and that is all that is necessary to add
a scope for calculating a quintile on a given column.  In this particular case,
we could have simply defined all the methods within the `class_methods` block
in the module within the `Student` class itself, thereby obviating the
extraneous module.

Ultimately, the version written with AREL produces the exact same output, but
with a lot of the hard-coded aspects stripped away.  While it is more difficult
to write up front, and more difficult to follow, each method returns an object
that is an `Arel::Node`, which has a `to_sql` method.  When composing queries in
this way for a real production application, this makes it possible to very
easily test the SQL generated, helping with long-term maintenance.

{% highlight ruby %}
module Quintile
  extend ActiveSupport::Concern

  class_methods do
    def quintile_on(column)
      scope "with_quintile_on_#{column}".to_sym, -> {
        from(wrapped_quintile_query(column))
      }
    end

    private

    def wrapped_quintile_query(column)
      Arel::Nodes::As.new(quintile_query(column), arel_table).to_sql
    end

    def quintile_query(column)
      table = quintile_table

      table.
        project(Arel::Nodes::SqlLiteral.new('*')).
        with(quintile_cte(table, column))
    end

    def quintile_table
      Arel::Table.new("quintile_table_for_#{table_name}_#{SecureRandom.hex(8)}")
    end

    def quintile_cte(table, column)
      Arel::Nodes::As.new(table, Arel::Nodes::Window.new.tap do |window|
        window.framing = quintile_cte_select(table, column)
      end)
    end

    def quintile_cte_select(table, column)
      Arel::Nodes::SelectCore.new.tap do |select|
        select.projections = [
          Arel::Nodes::SqlLiteral.new('*'),

          Arel::Nodes::As.new(
            quintile_cte_over(column),
            Arel::Nodes::SqlLiteral.new('quintile')
          )
        ]
        select.from = arel_table
      end
    end

    def quintile_cte_over(column)
      Arel::Nodes::Over.new(
        Arel::Nodes::SqlLiteral.new('ntile(5)'),
        Arel::Nodes::Window.new.order(column)
      )
    end
  end
end

class Student < ApplicationRecord
  include Quintile

  quintile_on :grade
end
{% endhighlight %}

As can be seen in our usage of the `Student` below, the named scope generated by
our class macro have a more fluent name than we had used previously, namely
stating on which column the quintile is being processed.  Another point of
interest for the query generated is our choice to define the `quintile_table`
method, such that it includes a random value in the name, with the intent of
making name collisions less likely when working with other scopes that require
table aliases.

{% highlight irb %}
>> Student.with_quintile_on_grade.first
   Student Load (928.2ms)  SELECT  "students".* FROM (WITH "quintile_table_for_students_b886c9319a75c9eb" AS (SELECT *, ntile(5) OVER (ORDER BY grade) AS quintile FROM "students") SELECT * FROM "quintile_table_for_students_b886c9319a75c9eb") AS "students" ORDER BY "students"."id" ASC LIMIT $1  [["LIMIT", 1]]
=> #<Student:0x0055d3e736a518 id: 1, name: "c4ca4238a0", grade: 29>
{% endhighlight %}

## Toward a Robust DSL

While this is a perfectly reasonable stopping point for this project, having
gotten exactly what we need from the database within the confines of a Rails
application, there is a lot more we could do.  It is easy to imagine, from atop
our module specific to quintiles for columns, writing a much more robust system
for defining these sorts of calculations.  The next logical steps are fairly
clear:

1. Abstract out the `quintile` aspect of the library, for the ability to have any quantile.
2. Create an class to encapsulate information about the `table` and `column`, to prevent the constant use as parameters.
3. Implement higher order class macros that can handle multiple definitions at once.

Now, `ActiveSUpport::Inflector` may not deal in quantiles, but it would be easy
enough to possess our own mapping between integers and words.  But all of this
is mere speculation, for we have accomplished what we set out to do.  Perhaps
we will someday return to this, but, for now, that is enough implementation.

## Ruminations

Instead, the path upon which we have trod during this exercise gives us a
contextual vantage point from which to discuss software construction,
methodology, and practice more generally.  We started as "close to the metal"
as necessary—inside PostgreSQL—but not at a layer so far away from our
problem domain that we would lose sight of goal.  In doing so, we learned about
and utilized some less common features of the database in an environment that
was conducive to exploring this fundamentals.  Had we started from ActiveRecord,
or worse AREL, our feedback loop would have been much slower as we coped with
extraneous details.  Instead, we did the simplest thing we could, found the
points at which it broke down, and iterated our implementation before even
attempting to integrate it.  And when we did so, we had to step back, and
reiterate the process, given our new set of constraints.

Often times, a problem will appear intractable when approached at too high a
level, without enough granular control, or without enough understanding of the
underlying architecture.  Stepping down helps in these cases, but does not
produce a satisfactory result.  After having gleaned what we could from the
database itself, we had to climb back up the
{% fancylink %}
  http://worrydream.com/LadderOfAbstraction/
  ladder of abstraction
{% endfancylink %}.
In doing so, we went marginally further than necessary, but showed how we could
remove a lot of the hard-coded details and make our software more robust.  We
had the opportunity to stop, but favored the more complete approach.  In
languages with code generation deeply ingrained, our solutions will often grow
to involve a level of abstraction that makes reuse trivial.  When it is
overkill and when it is ideal is a much more subjective question, based more on
the exigencies of the real world rather than what would be considered optimal
from a software implementation perspective.

And, finally, to get to the meta and talk about this last section from within
itself; it is always important to step back after an exercise that touches many
different pieces, contrived or experienced in practice, and ponder about what
can be gleaned from the process.  Just as higher order abstractions in
programming come from the recognition of patterns, so does it arise in higher
order thinking about programming.
