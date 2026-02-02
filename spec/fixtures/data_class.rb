class UserData
  attr_reader :name, :email, :age

  def initialize(name:, email:, age:)
    @name = name
    @email = email
    @age = age
  end
end
