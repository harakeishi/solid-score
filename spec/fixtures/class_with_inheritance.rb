class Animal
  def speak
    raise NotImplementedError
  end
end

class Dog < Animal
  def speak
    "woof"
  end

  def fetch(item)
    "fetches #{item}"
  end
end
