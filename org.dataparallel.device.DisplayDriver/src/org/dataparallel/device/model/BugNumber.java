package org.dataparallel.device.model;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

import javax.persistence.Basic;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.SequenceGenerator;
import javax.persistence.Table;
import javax.persistence.Version;

@Entity
@Table(name="DEVICE_BUGNUMBER")
public class BugNumber implements Serializable {
    private static final long serialVersionUID = 3132063814489287035L;

    @Id
    // keep the sequence column name under 30 chars to avoid an ORA-00972   
    @SequenceGenerator(name="DEV_SEQUENCE_BUGN", sequenceName="DEV_BUGN_SEQ", allocationSize=15)
    @GeneratedValue(generator="DEV_SEQUENCE_BUGN")
    @Column(name="BUG_ID")    
    private Long id;

    @Version
    @Column(name="BUG_VERSION")
    private int version;
    
    @Basic
    private long number;
    private int priority;
    private boolean assignedStatus;
    private String assignedTo;
    
    public BugNumber() {        
    }
    
    public BugNumber(String aNumber) {
        number = Integer.parseInt(aNumber);
    }
    
    public char[] getCharDigits() {
        return Long.toString(number).toCharArray();
    }
    
    public List<Integer> getIntDigits() {
        List<Integer> digits = new ArrayList<Integer>();
        for(Character aChar : getCharDigits()) {
            digits.add(new Integer(Character.getNumericValue(aChar.charValue())));            
        }
        return digits;
    }
    
    public int getLastDigit() {
        List<Integer> numbers = getIntDigits();        
        return numbers.get(numbers.size() - 1);
    }
    
    public long getNumber() {
        return number;
    }
    public void setNumber(long number) {
        this.number = number;
    }
    public int getPriority() {
        return priority;
    }
    public void setPriority(int priority) {
        this.priority = priority;
    }
    public boolean isAssignedStatus() {
        return assignedStatus;
    }
    public void setAssignedStatus(boolean assignedStatus) {
        this.assignedStatus = assignedStatus;
    }
    public String getAssignedTo() {
        return assignedTo;
    }
    public void setAssignedTo(String assignedTo) {
        this.assignedTo = assignedTo;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public int getVersion() {
        return version;
    }

    public void setVersion(int version) {
        this.version = version;
    }
    
    public static void main(String[] args) {
        BugNumber aBug = new BugNumber("266912");
        aBug.getCharDigits();
        aBug.getIntDigits();
        System.out.println(aBug.getNumber());
    }
}
