from src.main import main


def test_main_prints_greeting(capsys):
    main()

    result = capsys.readouterr().out

    assert result == "Hello from python-template\n"
