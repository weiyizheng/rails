# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", path: "~/projects/rails"
  gem "sqlite3"
  gem "pry-rails"
  gem 'pry-byebug'
end

require "active_record"
require "minitest/autorun"
require "logger"

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :content
  end

  create_table :authors, force: true do |t|
    t.integer :post_id
    t.string :first_name
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
    t.string :title
  end
end

class Post < ActiveRecord::Base
  has_many :comments
  has_one :author
  accepts_nested_attributes_for :comments, validate_on_create: true
  validates :content, uniqueness: true
end

class Author < ActiveRecord::Base
  validates :first_name, presence: true
end

class Comment < ActiveRecord::Base
  belongs_to :post
  validates :title, presence: true
  validates :title, uniqueness: { scope: [:post],
                                  message: "should happen once per post" }
end

class BugTest < Minitest::Test
  def test_create_two_children_that_violates_uniqueness_validation_should_fail
    post = Post.new({content: 'post content', comments_attributes: [{title: 'same'}, {title: 'same'}]})
    post.save
    assert_equal 0, post.comments.count
  end

  def test_create_one_child_that_violates_uniqueness_validation_should_fail
    post = Post.create({content: 'post content'})
    first_comment = post.comments.create({title: 'same'})
    post.assign_attributes({comments_attributes: [{id: first_comment.id}, {title: 'same'}]})
    post.save
    assert_equal 1, post.comments.count
  end
end
