import time
from datetime import datetime, timezone, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
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
    options.add_argument("--incognito")
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.100 Safari/537.36"
    options.add_argument("--user-agent={}".format(user_agent))
    driver = webdriver.Chrome('chromedriver', options=options)
    return driver


is_running = True
scheduler = BackgroundScheduler()
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


def login(driver):
    script_url = "https://www.google.com?hl=en"
    driver.get(script_url)
    driver = read_cookies(driver)
    driver.get(get_config()["script_url"])
    code_input_element = WebDriverWait(driver, 100).until(
        EC.presence_of_element_located((By.TAG_NAME, "textarea")))
    code_input_element.send_keys(Keys.CONTROL, 'a')
    init_script = code_input_element.get_attribute('value')
    code_input_element.send_keys(Keys.BACKSPACE)
    cookies_code = '!echo \'{}\' >/tmp/cookies.json'.format(
        json.dumps(driver.get_cookies()))
    code_input_element.send_keys(cookies_code)
    code_run_seletor = "div.main-content > div.codecell-input-output > div.inputarea.horizontal.layout.code > div.cell-gutter > div > div"
    code_run_element = WebDriverWait(driver, 100).until(
        EC.element_to_be_clickable((By.CSS_SELECTOR, code_run_seletor)))
    code_run_element.click()
    code_run_element = WebDriverWait(driver, 100).until(
        EC.element_to_be_clickable((By.CSS_SELECTOR, code_run_seletor)))
    driver.find_element_by_css_selector(
        'div.main-content > div.codecell-input-output > div.inputarea.horizontal.layout.code > div.editor.flex > div > div.CodeMirror-scroll > div.CodeMirror-sizer > div > div').click()
    code_input_element.send_keys(Keys.CONTROL, 'a')
    code_input_element.send_keys(Keys.BACKSPACE)
    code_input_element.send_keys(init_script)
    code_run_element.click()
    time.sleep(2)
    tree = etree.HTML(driver.page_source)
    statues_description = tree.xpath('//div[2]/paper-icon-button/@title')[0]
    write_log('当前状态:'+statues_description)


def fresh_page(driver):
    write_log("刷新页面")
    driver.refresh()
    driver.implicitly_wait(20)
    driver.switch_to.alert.accept()
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
            driver.add_cookie(cookie)
    return driver


# @scheduler.scheduled_job("cron", CronTrigger.from_crontab(get_config()["crontab"]))
def reset_job():
    write_log("开始重置")
    is_running = False
    globel_driver.find_element_by_xpath(
        '//*[@id="runtime-menu-button"]/div/div/div[1]').click()
    globel_driver.find_element_by_xpath('//*[@id=":21"]').click()
    globel_driver.find_element_by_xpath('//*[@id="ok"]').click()
    time.sleep(5)
    fresh_page(globel_driver)


def run_deamon(driver):
    save_cookie(driver)
    duration = 0
    error_count = 0
    write_log("开始进程守护")
    while is_running:
        for i in range(100):
            try:
                save_cookie(globel_driver)
                tree = etree.HTML(driver.page_source)
                if len(tree.xpath('//div[2]/paper-icon-button/@title')) == 0:
                    time.sleep(0.1)
                    continue
                statues_description = tree.xpath(
                    '//div[2]/paper-icon-button/@title')[0]
                run_seletor = "div.main-content > div.codecell-input-output > div.inputarea.horizontal.layout.code > div.cell-gutter > div > div"
                run_element = WebDriverWait(driver, 1).until(
                    EC.element_to_be_clickable((By.CSS_SELECTOR, run_seletor)))
                if duration > 3600 or (
                        'Run cell' in statues_description
                        and not run_element) or len(
                    tree.xpath("/html/body/iron-overlay-backdrop")
                ) > 0 or error_count > 10:
                    duration = 0
                    error_count = 0
                    driver = fresh_page(driver)
                    continue
                if 'Run cell' in statues_description and 'currently executing' not in statues_description and run_element:
                    write_log('点击运行：'+statues_description)
                    code_run_seletor = "div.main-content > div.codecell-input-output > div.inputarea.horizontal.layout.code > div.cell-gutter > div > div"
                    code_run_element = WebDriverWait(driver, 100).until(
                        EC.element_to_be_clickable((By.CSS_SELECTOR, code_run_seletor)))
                    code_run_element.click()
                    time.sleep(50)
                elif 'currently executing' in statues_description:
                    time.sleep(1)
                    duration += 1
                if duration % 100 == 0:
                    write_log("当前duration：{}".format(duration))
                continue
            except Exception as e:
                error_count += 1
                write_log("error 守护进程:{}".format(e))
                time.sleep(0.1)
        if get_config()["script_url"] != driver.current_url:
            break
    if not is_running:
        time.sleep(10)
    driver.close()
    write_log('执行结束')


if __name__ == "__main__":
    scheduler.add_job(reset_job, 'cron', hour=get_config()["crontab"])
    scheduler.start()
    login(globel_driver)
    run_deamon(globel_driver)
