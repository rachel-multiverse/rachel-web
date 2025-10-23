defmodule RachelWeb.CoreComponentsTest do
  use RachelWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import RachelWeb.CoreComponents

  describe "flash/1" do
    test "renders info flash message" do
      assigns = %{
        kind: :info,
        flash: %{"info" => "Success message"},
        id: "test-flash"
      }

      html = rendered_to_string(~H"""
      <.flash kind={@kind} flash={@flash} id={@id} />
      """)

      assert html =~ "Success message"
      assert html =~ "alert-info"
      assert html =~ "test-flash"
    end

    test "renders error flash message" do
      assigns = %{
        kind: :error,
        flash: %{"error" => "Error message"},
        id: "error-flash"
      }

      html = rendered_to_string(~H"""
      <.flash kind={@kind} flash={@flash} id={@id} />
      """)

      assert html =~ "Error message"
      assert html =~ "alert-error"
    end

    test "renders flash with title" do
      assigns = %{
        kind: :info,
        flash: %{},
        title: "Important",
        id: "titled-flash"
      }

      html = rendered_to_string(~H"""
      <.flash kind={@kind} flash={@flash} title={@title} id={@id}>
        Message content
      </.flash>
      """)

      assert html =~ "Important"
      assert html =~ "Message content"
    end

    test "generates default id when not provided" do
      assigns = %{
        kind: :info,
        flash: %{"info" => "Test"}
      }

      html = rendered_to_string(~H"""
      <.flash kind={@kind} flash={@flash} />
      """)

      assert html =~ "flash-info"
    end
  end

  describe "button/1" do
    test "renders primary button" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.button>Click me</.button>
      """)

      assert html =~ "Click me"
      assert html =~ "btn"
    end

    test "renders button with phx-disable-with" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.button phx-disable-with="Saving...">Save</.button>
      """)

      assert html =~ "Save"
      assert html =~ "Saving..."
    end
  end

  describe "input/1" do
    test "renders text input" do
      form = to_form(%{"name" => ""}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:name]} type="text" label="Name" />
      """)

      assert html =~ "Name"
      assert html =~ ~s(type="text")
      assert html =~ ~s(name="user[name]")
    end

    test "renders checkbox input" do
      form = to_form(%{"agree" => false}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:agree]} type="checkbox" label="I agree" />
      """)

      assert html =~ "I agree"
      assert html =~ ~s(type="checkbox")
    end

    test "renders select input" do
      form = to_form(%{"role" => ""}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:role]} type="select" label="Role" options={[{"Admin", "admin"}, {"User", "user"}]} />
      """)

      assert html =~ "Role"
      assert html =~ "Admin"
      assert html =~ "User"
    end

    test "renders textarea input" do
      form = to_form(%{"bio" => ""}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:bio]} type="textarea" label="Bio" />
      """)

      assert html =~ "Bio"
      assert html =~ "<textarea"
    end

    test "renders email input" do
      form = to_form(%{"email" => ""}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:email]} type="email" label="Email" />
      """)

      assert html =~ "Email"
      assert html =~ ~s(type="email")
    end

    test "renders password input" do
      form = to_form(%{"password" => ""}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:password]} type="password" label="Password" />
      """)

      assert html =~ "Password"
      assert html =~ ~s(type="password")
    end

    test "renders hidden input" do
      form = to_form(%{"id" => "123"}, as: :user)
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:id]} type="hidden" />
      """)

      assert html =~ ~s(type="hidden")
      assert html =~ ~s(value="123")
    end

    test "displays error messages" do
      form = to_form(%{"email" => ""}, as: :user)
      form = %{form | errors: [email: {"can't be blank", [validation: :required]}]}
      assigns = %{form: form}

      html = rendered_to_string(~H"""
      <.input field={@form[:email]} type="email" label="Email" />
      """)

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "header/1" do
    test "renders header with title" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.header>
        Page Title
        <:subtitle>Subtitle text</:subtitle>
      </.header>
      """)

      assert html =~ "Page Title"
      assert html =~ "Subtitle text"
    end

    test "renders header with actions" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.header>
        Title
        <:actions>
          <button>Action</button>
        </:actions>
      </.header>
      """)

      assert html =~ "Title"
      assert html =~ "Action"
    end
  end

  describe "table/1" do
    test "renders table with rows" do
      assigns = %{
        users: [
          %{id: 1, name: "Alice"},
          %{id: 2, name: "Bob"}
        ]
      }

      html = rendered_to_string(~H"""
      <.table id="users" rows={@users}>
        <:col :let={user} label="Name">{user.name}</:col>
      </.table>
      """)

      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "renders table with action column" do
      assigns = %{
        users: [%{id: 1, name: "Alice"}]
      }

      html = rendered_to_string(~H"""
      <.table id="users" rows={@users}>
        <:col :let={user} label="Name">{user.name}</:col>
        <:action :let={user}>
          <button>Edit</button>
        </:action>
      </.table>
      """)

      assert html =~ "Edit"
    end
  end

  describe "list/1" do
    test "renders definition list" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.list>
        <:item title="Name">Alice</:item>
        <:item title="Email">alice@example.com</:item>
      </.list>
      """)

      assert html =~ "Name"
      assert html =~ "Alice"
      assert html =~ "Email"
      assert html =~ "alice@example.com"
    end
  end

  describe "icon/1" do
    test "renders heroicon" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.icon name="hero-check" />
      """)

      assert html =~ "hero-check"
    end

    test "renders icon with class" do
      assigns = %{}

      html = rendered_to_string(~H"""
      <.icon name="hero-x-mark" class="size-4" />
      """)

      assert html =~ "size-4"
    end
  end

  describe "show/2" do
    test "creates JS command to show element" do
      result = show("#my-element")
      assert %Phoenix.LiveView.JS{} = result
    end

    test "accepts existing JS commands" do
      js = %Phoenix.LiveView.JS{}
      result = show(js, "#my-element")
      assert %Phoenix.LiveView.JS{} = result
    end
  end

  describe "hide/2" do
    test "creates JS command to hide element" do
      result = hide("#my-element")
      assert %Phoenix.LiveView.JS{} = result
    end

    test "accepts existing JS commands" do
      js = %Phoenix.LiveView.JS{}
      result = hide(js, "#my-element")
      assert %Phoenix.LiveView.JS{} = result
    end
  end

  describe "translate_error/1" do
    test "translates error tuple" do
      result = translate_error({"must be at least %{count} characters", [count: 5]})
      assert result == "must be at least 5 characters"
    end

    test "handles error without interpolation" do
      result = translate_error({"is invalid", []})
      assert result == "is invalid"
    end
  end

  describe "translate_errors/2" do
    test "translates list of errors" do
      errors = [
        {:email, {"can't be blank", [validation: :required]}},
        {:email, {"is invalid", [validation: :format]}}
      ]

      result = translate_errors(errors, :email)
      assert is_list(result)
      assert length(result) == 2
      assert "can't be blank" in result
      assert "is invalid" in result
    end

    test "filters by field" do
      errors = [
        {:email, {"can't be blank", [validation: :required]}},
        {:password, {"is too short", [count: 8]}}
      ]

      result = translate_errors(errors, :email)
      assert length(result) == 1
      assert "can't be blank" in result
      refute "is too short" in result
    end

    test "handles empty error list" do
      result = translate_errors([], :email)
      assert result == []
    end
  end
end
