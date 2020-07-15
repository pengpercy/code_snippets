import time
from datetime import datetime, timezone, timedelta
from lxml import etree
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import json


def get_config():
    """读取配置信息"""
    with open("/tmp/colab_daemon.json", "r") as fp:
        return json.load(fp)


def get_driver():
    """实例化webdriver"""
    options = webdriver.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--incognito')
    options.add_argument('--disable-notifications')
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36"
    options.add_argument("--user-agent={}".format(user_agent))
    driver = webdriver.Chrome('chromedriver', options=options)
    return driver


is_running = True
globel_driver = get_driver()


def write_log(message):
    """记录日志"""
    timenow = datetime.utcnow().replace(tzinfo=timezone.utc).astimezone(
        timezone(timedelta(hours=8)))
    file_name = './log/colab_daemon{}.log'.format(
        timenow.strftime("%Y%m"))
    with open(file_name, 'a+', encoding='utf-8') as f:
        message = '{} {}'.format(timenow.strftime("%m-%d %H:%M:%S"), message)
        print(message)
        f.write(message + "\n")
        f.close()


def execute_code(driver):
    """等待加载完成"""
    for i in range(1000):
        tree = etree.HTML(driver.page_source)
        if len(tree.xpath('//div[2]/paper-icon-button')) > 0:
            print("加载完成")
            break
        else:
            time.sleep(0.1)
            continue

    code_run_element = driver.execute_script(
        '''return document.querySelector("div.main-content > div.codecell-input-output > div.inputarea.horizontal.layout.code > div.cell-gutter > div > colab-run-button").shadowRoot.querySelector("div > div.cell-execution-indicator");''')
    code_run_element.click()
    time.sleep(3)


def get_running_status(driver):
    """获取最新状态"""
    tree = etree.HTML(driver.page_source)
    return tree.xpath('//colab-run-button/@title')[0]


def login(driver):
    script_url = "https://www.google.com?hl=en"
    driver.get(script_url)
    driver = read_cookies(driver)
    driver.get(get_config()["script_url"])
    execute_code(driver)
    if 'Interrupt execution' not in get_running_status(driver):
        execute_code(driver)
        time.sleep(3)
        # code_input_element.send_keys(Keys.CONTROL, Keys.ENTER)
    write_log('当前状态:'+get_running_status(driver))
    run_deamon(driver)


def fresh_page(driver):
    try:
        write_log("刷新页面:"+get_running_status(driver))
        driver.refresh()
        driver.switch_to_alert().accept()
    except Exception as e:
        write_log("刷新报错:{}".format(e))
        driver.implicitly_wait(20)
    return driver


def save_cookie(driver):
    """保存cookie"""
    cookies = driver.get_cookies()
    with open("/tmp/cookies.json", "w") as fp:
        json.dump(cookies, fp)
        fp.close()


def read_cookies(driver):
    """读取cookies"""
    with open("/tmp/cookies.json", "r") as fp:
        cookies = json.load(fp)
        for cookie in cookies:
            if 'expiry' in cookie:
                del cookie['expiry']
            if 'sameSite' in cookie:
                del cookie['sameSite']
            driver.add_cookie(cookie)
    return driver


def run_deamon(driver):
    duration = 0
    error_count = 0
    write_log("开始进程守护")
    while is_running:
        for i in range(100):
            try:
                save_cookie(driver)
                tree = etree.HTML(driver.page_source)
                if len(tree.xpath('//colab-run-button/@title')) == 0:
                    time.sleep(0.1)
                    continue
                statues_description = get_running_status(driver)
                if len(tree.xpath("/html/body/iron-overlay-backdrop")) > 0:
                    driver.find_element_by_xpath('//*[@id="ok"]').click()
                    break
                if duration > 3600 or error_count > 10:
                    duration = 0
                    error_count = 0
                    driver = fresh_page(driver)
                    execute_code(driver)
                    continue
                if 'Interrupt execution' not in statues_description:
                    write_log('点击运行前'+statues_description)
                    execute_code(driver)
                    time.sleep(5)
                    write_log('点击运行后:'+get_running_status(driver))
                    time.sleep(30)
                    if 'Interrupt execution' not in get_running_status(driver):
                        fresh_page(driver)
                elif 'Interrupt execution' in get_running_status(driver):
                    time.sleep(1)
                    duration += 1
                if duration % 100 == 0:
                    write_log("当前duration：{}, {}".format(
                        duration, get_running_status(driver)))
                continue
            except Exception as e:
                error_count += 1
                write_log("error 守护进程:{}".format(e))
                time.sleep(0.1)
        if get_config()["script_url"] != driver.current_url:
            break
    if not is_running:
        time.sleep(10)
    write_log("重新登录")
    globel_driver = driver


if __name__ == "__main__":
    login(globel_driver)
