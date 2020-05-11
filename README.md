# Rails Json Serializer
A Rails gem that supports nested automatic eager-loading on assocations (via includes) and also supports Rails caching.
It utilizes the Rails `as_json` method, with the JSON queries building the `as_json` options.
It will inject the serializer methods into your classes.

Tested on w/ Rspec:<br/>
Rails 5.1.7, 5.2.2, 6.0.3<br/>
Ruby 2.4.5, 2.5.8
```
# Add to Gemfile
gem 'rails_json_serializer'
```

create init file: `config/initializers/serializer.rb`
and populate it with the following:
```
require "serializer"

# default values shown
Serializer.configure do |config|
  # Disable all eager-loading by setting to false
  config.enable_includes = true
  
  # Set your own default cache expiration
  config.default_cache_time = 360 # minutes
  
  # You can disable caching at the serializer level by leaving out the `cache_key` or setting `cache_for: nil`
  # You can also specify a different caching time using `cache_for`
  config.disable_model_caching = false
  
  # Sends caching information to the Rails logger (info) if true
  config.debug = false
end
```

Now you can create a folder and start adding your serializer files into it: `app/serializers`

## Ex 1.
If you have a User class, you can then create the file `app/serializers/user_serializer.rb` and populate it with the following:
```
module UserSerializer
  include ApplicationSerializer

  # This method will automatically be included in the module, via the ApplicationSerializer, but you can override it here.
  def serializer_query options = {}
    {
      :include => {
      },
      :methods => %w(),
      cache_key: __callee__,
    }
  end
end
```
Your User class will then have access to the class method: `User.serializer`, the instance method `User.first.serializer`, and also access to the query method: `User.serializer_query`

## Ex 2
```
class User
  has_many :friendly_tos
  has_many :friends, through: :friendly_tos, source: :is_friendly_with
  accepts_nested_attributes_for :friends
end

# Join table that joins users to their friends
class FriendlyTo
  belongs_to :user
  belongs_to :is_friendly_with, :class_name => "User"
end
```
```
module UserSerializer
  include ApplicationSerializer

  def serializer_query options = {}
    {
      :include => {
        :friends => User.tiny_serializer_query.merge({as: :friends_attributes}),
      },
      :methods => %w(),
      cache_key: __callee__,
    }
  end
  
  def tiny_serializer_query options = {}
    {
      cache_key: __callee__,
    }
  end
end
```
We've updated the Rails `as_json` method to support aliasing via the `:as` key.
In addition to the User object having the class and instance `serializer` method, it will now also have the `tiny_serializer` methods as well.
## Skip eagerloading
Can optionally use a `skip_serializer_includes` option on serializers to skip eagerloading.
`User.first.serializer({skip_eager_loading: true})`
or 
`User.serializer({skip_eager_loading: true})`

Or define it at the JSON query level:
```
module UserSerializer
  include ApplicationSerializer
  def serializer_query options = {}
    {
      :include => {
        :friends => User.serializer_query.merge({as: :friends_attributes}),
      },
      :methods => %w(),
      cache_key: __callee__,
      cache_for: nil,
      skip_eager_loading: true
    }
  end
end
```
## Callback Hooks
You'll also have the object method to clear an object's cache: `clear_serializer_cache`. Based on your implementation, you may want the following callback hooks in your rails models:
```
after_commit :clear_serializer_cache
after_touch :clear_serializer_cache
```
## Ex 3
```
class User
  has_many :friendly_tos
  has_many :friends, through: :friendly_tos, source: :is_friendly_with
  accepts_nested_attributes_for :friends

  after_commit :clear_serializer_cache
  after_touch :clear_serializer_cache
end

```
